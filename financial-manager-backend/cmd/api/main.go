// Command api runs the HTTP API server for FinancialManager.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/redis/go-redis/v9"

	"financial-manager-backend/internal/auth"
	"financial-manager-backend/internal/email"
	"financial-manager-backend/internal/identities"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/httpserver"
	"financial-manager-backend/internal/platform/observability"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/redisclient"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

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

	checks := httpserver.HealthChecks{
		Database: func(ctx context.Context) error { return dbPool.Ping(ctx) },
		Redis:    func(ctx context.Context) error { return redisClient.Ping(ctx).Err() },
	}

	router := httpserver.New(logger, checks)
	mountRoutes(router, dbPool, redisClient, cfg, logger)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		logger.Info("http_server_starting", slog.String("addr", cfg.HTTPAddr))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	select {
	case err := <-serveErr:
		return fmt.Errorf("http server: %w", err)
	case <-ctx.Done():
		logger.Info("shutdown_signal_received")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}

	logger.Info("shutdown_complete")
	return nil
}

// mountRoutes wires each module's repositories, services, and HTTP
// handlers onto the router. Kept as one function (rather than spread
// across the module packages) so the dependency graph between modules is
// visible in one place.
func mountRoutes(router chi.Router, dbPool *database.Pool, redisClient *redis.Client, cfg config.Config, logger *slog.Logger) {
	usersRepo := users.NewRepository(dbPool)
	walletsRepo := wallets.NewRepository(dbPool)
	transactionsRepo := transactions.NewRepository(dbPool)
	credentialsRepo := auth.NewCredentialsRepository(dbPool)
	sessionsRepo := auth.NewSessionRepository(dbPool)
	emailVerifyRepo := auth.NewEmailVerificationTokenRepository(dbPool)
	passwordResetRepo := auth.NewPasswordResetTokenRepository(dbPool)
	identitiesRepo := identities.NewRepository(dbPool)

	var googleVerifier identities.GoogleIDTokenVerifier = identities.RealGoogleIDTokenVerifier{
		Audiences: cfg.GoogleClientIDs,
	}

	authService := auth.NewService(auth.Deps{
		DB:              dbPool,
		Users:           usersRepo,
		Credentials:     credentialsRepo,
		Sessions:        sessionsRepo,
		EmailVerify:     emailVerifyRepo,
		PasswordReset:   passwordResetRepo,
		Wallets:         walletsRepo,
		Transactions:    transactionsRepo,
		Identities:      identitiesRepo,
		GoogleVerifier:  googleVerifier,
		TicketStore:     identities.NewTicketStore(redisClient),
		RateLimiter:     ratelimit.New(redisClient),
		EmailSender:     email.DevLogSender{Logger: logger},
		Clock:           clock.System{},
		JWTSigningKey:   cfg.JWTSigningKey,
		AccessTokenTTL:  cfg.AccessTokenTTL,
		RefreshTokenTTL: cfg.RefreshTokenTTL,
	})
	authHandler := auth.NewHandler(authService)
	authHandler.MountPublic(router)
	authHandler.MountGooglePublic(router)

	usersHandler := users.NewHandler(users.NewService(usersRepo))
	walletsHandler := wallets.NewHandler(walletsRepo)

	transactionsService := transactions.NewService(transactions.Deps{
		DB:           dbPool,
		Transactions: transactionsRepo,
		Wallets:      walletsRepo,
		Audit:        transactions.NewAuditRepository(dbPool),
		Clock:        clock.System{},
	})
	transactionsHandler := transactions.NewHandler(transactionsService)

	router.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSigningKey))
		authHandler.MountProtected(r)
		authHandler.MountGoogleProtected(r)
		usersHandler.Mount(r)
		walletsHandler.Mount(r)
		transactionsHandler.Mount(r)
	})
}
