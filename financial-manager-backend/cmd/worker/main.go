// Command worker runs asynchronous background jobs: balance reconciliation
// (plan.md section 13.6, 22.3) and orphan media cleanup (section 16.6).
// Exports, deferred account deletion, and email sending (section 10.8) are
// added alongside the features that need them.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"financial-manager-backend/internal/media"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/observability"
	"financial-manager-backend/internal/platform/redisclient"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/wallets"
)

const reconciliationInterval = time.Hour
const mediaCleanupInterval = time.Hour

// mediaOrphanGraceHours is how long an unreferenced asset survives before
// cleanup (plan.md section 16.6: "Pulire asset orfani dopo un periodo di
// grazia") — long enough that an in-progress "pick an image, then fill the
// rest of the form" session never loses its upload mid-edit.
const mediaOrphanGraceHours = 24

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	logger := observability.NewLogger(cfg)
	slog.SetDefault(logger)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	dbPool, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect database: %w", err)
	}
	defer dbPool.Close()

	redisClient, err := redisclient.Connect(ctx, cfg.RedisAddr, cfg.RedisPassword)
	if err != nil {
		return fmt.Errorf("connect redis: %w", err)
	}
	defer redisClient.Close()

	objectStore, err := storage.NewMinIOStore(ctx, storage.MinIOConfig{
		Endpoint:  cfg.ObjectStorageEndpoint,
		AccessKey: cfg.ObjectStorageAccessKey,
		SecretKey: cfg.ObjectStorageSecretKey,
		Bucket:    cfg.ObjectStorageBucket,
		UseSSL:    cfg.ObjectStorageUseSSL,
	})
	if err != nil {
		return fmt.Errorf("connect object storage: %w", err)
	}

	transactionsService := transactions.NewService(transactions.Deps{
		DB:           dbPool,
		Transactions: transactions.NewRepository(dbPool),
		Wallets:      wallets.NewRepository(dbPool),
		Audit:        transactions.NewAuditRepository(dbPool),
		Clock:        clock.System{},
	})

	mediaService := media.NewService(media.Deps{
		Repo: media.NewRepository(dbPool), Store: objectStore,
		MaxUploadBytes: cfg.MaxUploadBytes, AllowedImageTypes: cfg.AllowedImageTypes,
	})

	logger.Info("worker_started")

	runReconciliation(ctx, logger, transactionsService)
	runMediaCleanup(ctx, logger, mediaService)

	reconciliationTicker := time.NewTicker(reconciliationInterval)
	defer reconciliationTicker.Stop()
	mediaCleanupTicker := time.NewTicker(mediaCleanupInterval)
	defer mediaCleanupTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			logger.Info("worker_shutdown")
			return nil
		case <-reconciliationTicker.C:
			runReconciliation(ctx, logger, transactionsService)
		case <-mediaCleanupTicker.C:
			runMediaCleanup(ctx, logger, mediaService)
		}
	}
}

func runMediaCleanup(ctx context.Context, logger *slog.Logger, svc *media.Service) {
	deleted, err := svc.CleanupOrphans(ctx, mediaOrphanGraceHours)
	if err != nil {
		logger.Error("media_cleanup_failed", slog.String("error", err.Error()))
		return
	}
	logger.Info("media_cleanup_ok", slog.Int("deleted", deleted))
}

// runReconciliation compares every wallet's stored balance against its
// ledger and logs (never silently auto-corrects — plan.md section 13.6:
// "non correggere automaticamente senza audit") any mismatch found.
func runReconciliation(ctx context.Context, logger *slog.Logger, svc *transactions.Service) {
	mismatches, err := svc.Reconcile(ctx)
	if err != nil {
		logger.Error("reconciliation_failed", slog.String("error", err.Error()))
		return
	}

	if len(mismatches) == 0 {
		logger.Info("reconciliation_ok")
		return
	}

	for _, m := range mismatches {
		logger.Warn("reconciliation_mismatch",
			slog.String("wallet_id", m.WalletID.String()),
			slog.String("user_id", m.UserID.String()),
			slog.Int64("stored_balance_minor", m.StoredBalance),
			slog.Int64("recalculated_sum_minor", m.RecalculatedSum),
		)
	}
}
