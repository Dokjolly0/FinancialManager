// Command worker runs asynchronous background jobs: balance reconciliation
// (plan.md section 13.6, 22.3), orphan media cleanup (section 16.6), and
// deferred account-deletion purge (section 20.3). Exports run synchronously
// inside the API for now (see internal/export's doc comments) and email
// sending (section 10.8) is added alongside the feature that needs it.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/media"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/observability"
	"financial-manager-backend/internal/platform/redisclient"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

const reconciliationInterval = time.Hour
const mediaCleanupInterval = time.Hour
const accountPurgeInterval = time.Hour

// mediaOrphanGraceHours is how long an unreferenced asset survives before
// cleanup (plan.md section 16.6: "Pulire asset orfani dopo un periodo di
// grazia") — long enough that an in-progress "pick an image, then fill the
// rest of the form" session never loses its upload mid-edit.
const mediaOrphanGraceHours = 24

// accountDeletionGraceDays is how long a pending_deletion account's data
// survives before the purge job scrubs it (plan.md section 20.3
// "possibile periodo di grazia") — there's no "cancel deletion" flow yet,
// so this window is currently the only chance to notice an accidental
// deletion request before it's irreversible.
const accountDeletionGraceDays = 30

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

	transactionsRepo := transactions.NewRepository(dbPool)
	transactionsService := transactions.NewService(transactions.Deps{
		DB:           dbPool,
		Transactions: transactionsRepo,
		Wallets:      wallets.NewRepository(dbPool),
		Audit:        transactions.NewAuditRepository(dbPool),
		Clock:        clock.System{},
	})

	mediaRepo := media.NewRepository(dbPool)
	mediaService := media.NewService(media.Deps{
		Repo: mediaRepo, Store: objectStore,
		MaxUploadBytes: cfg.MaxUploadBytes, AllowedImageTypes: cfg.AllowedImageTypes,
	})

	usersRepo := users.NewRepository(dbPool)
	categoriesRepo := categories.NewRepository(dbPool)
	purger := accountPurger{
		users: usersRepo, categories: categoriesRepo, transactions: transactionsRepo,
		mediaRepo: mediaRepo, mediaService: mediaService, clock: clock.System{},
	}

	logger.Info("worker_started")

	runReconciliation(ctx, logger, transactionsService)
	runMediaCleanup(ctx, logger, mediaService)
	runAccountPurge(ctx, logger, purger)

	reconciliationTicker := time.NewTicker(reconciliationInterval)
	defer reconciliationTicker.Stop()
	mediaCleanupTicker := time.NewTicker(mediaCleanupInterval)
	defer mediaCleanupTicker.Stop()
	accountPurgeTicker := time.NewTicker(accountPurgeInterval)
	defer accountPurgeTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			logger.Info("worker_shutdown")
			return nil
		case <-reconciliationTicker.C:
			runReconciliation(ctx, logger, transactionsService)
		case <-mediaCleanupTicker.C:
			runMediaCleanup(ctx, logger, mediaService)
		case <-accountPurgeTicker.C:
			runAccountPurge(ctx, logger, purger)
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

// accountPurger bundles what runAccountPurge needs to carry out plan.md
// section 20.3 step 7 ("job di rimozione dati e asset") for one account:
// detach every media reference, delete the now-unreferenced assets, then
// anonymize the user row. The ledger itself is kept — see
// users.Repository.Purge's doc comment.
type accountPurger struct {
	users        *users.Repository
	categories   *categories.Repository
	transactions *transactions.Repository
	mediaRepo    *media.Repository
	mediaService *media.Service
	clock        clock.Clock
}

func (p accountPurger) purgeOne(ctx context.Context, userID uuid.UUID) error {
	if err := p.transactions.ClearMediaForUser(ctx, userID); err != nil {
		return fmt.Errorf("clear transaction media: %w", err)
	}
	if err := p.categories.ClearIconMediaForOwner(ctx, userID); err != nil {
		return fmt.Errorf("clear category icon media: %w", err)
	}
	if err := p.users.Purge(ctx, userID); err != nil {
		return fmt.Errorf("purge user record: %w", err)
	}

	assets, err := p.mediaRepo.ListAllForOwner(ctx, userID)
	if err != nil {
		return fmt.Errorf("list media assets: %w", err)
	}
	for _, asset := range assets {
		if err := p.mediaService.Delete(ctx, userID, asset.ID); err != nil {
			return fmt.Errorf("delete media asset %s: %w", asset.ID, err)
		}
	}
	return nil
}

func runAccountPurge(ctx context.Context, logger *slog.Logger, p accountPurger) {
	cutoff := p.clock.Now().AddDate(0, 0, -accountDeletionGraceDays)
	pending, err := p.users.ListPendingDeletionOlderThan(ctx, cutoff)
	if err != nil {
		logger.Error("account_purge_list_failed", slog.String("error", err.Error()))
		return
	}

	purged := 0
	for _, u := range pending {
		if err := p.purgeOne(ctx, u.ID); err != nil {
			logger.Error("account_purge_failed", slog.String("user_id", u.ID.String()), slog.String("error", err.Error()))
			continue
		}
		purged++
	}
	logger.Info("account_purge_ok", slog.Int("purged", purged), slog.Int("pending", len(pending)))
}
