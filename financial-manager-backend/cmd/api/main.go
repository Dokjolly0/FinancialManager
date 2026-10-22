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

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/auth"
	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/email"
	"financial-manager-backend/internal/export"
	"financial-manager-backend/internal/identities"
	"financial-manager-backend/internal/media"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/httpserver"
	"financial-manager-backend/internal/platform/metrics"
	"financial-manager-backend/internal/platform/observability"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/redisclient"
	"financial-manager-backend/internal/platform/reportcache"
	"financial-manager-backend/internal/platform/secretbox"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/reports"
	"financial-manager-backend/internal/templates"
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
	metrics.RegisterDBPool(dbPool.Pool)

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

	checks := httpserver.HealthChecks{
		Database: func(ctx context.Context) error { return dbPool.Ping(ctx) },
		Redis:    func(ctx context.Context) error { return redisClient.Ping(ctx).Err() },
	}

	router := httpserver.New(logger, checks, cfg.HTTPRequestTimeout, cfg.TrustedProxies)
	if err := mountRoutes(router, dbPool, redisClient, objectStore, cfg, logger); err != nil {
		return err
	}

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
func mountRoutes(router chi.Router, dbPool *database.Pool, redisClient *redis.Client, objectStore storage.Store, cfg config.Config, logger *slog.Logger) error {
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

	rateLimiter := ratelimit.New(redisClient)

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
		RateLimiter:     rateLimiter,
		EmailSender:     email.DevLogSender{Logger: logger},
		Clock:           clock.System{},
		JWTSigningKey:   cfg.JWTSigningKey,
		AccessTokenTTL:  cfg.AccessTokenTTL,
		RefreshTokenTTL: cfg.RefreshTokenTTL,
	})
	authHandler := auth.NewHandler(authService)
	router.Group(func(r chi.Router) {
		r.Use(httpserver.Timeout(cfg.HTTPRequestTimeout))
		authHandler.MountPublic(r)
		authHandler.MountGooglePublic(r)
	})

	usersHandler := users.NewHandler(users.NewService(usersRepo))
	walletsHandler := wallets.NewHandler(walletsRepo)

	categoriesRepo := categories.NewRepository(dbPool)
	categoriesHandler := categories.NewHandler(categories.NewService(categoriesRepo))

	templatesRepo := templates.NewRepository(dbPool)
	templatesHandler := templates.NewHandler(templates.NewService(templatesRepo))

	var searchProvider media.ImageSearchProvider = media.StubImageSearchProvider{}
	if cfg.ImageSearchProvider == "unsplash" {
		searchProvider = media.NewUnsplashProvider(cfg.ImageSearchAPIKey)
	}
	mediaRepo := media.NewRepository(dbPool)
	mediaService := media.NewService(media.Deps{
		Repo: mediaRepo, Store: objectStore, Search: searchProvider,
		MaxUploadBytes: cfg.MaxUploadBytes, AllowedImageTypes: cfg.AllowedImageTypes,
		RateLimiter: rateLimiter,
	})
	mediaHandler := media.NewHandler(mediaService, cfg.MaxUploadBytes)

	reportCache := reportcache.New(redisClient)

	transactionsService := transactions.NewService(transactions.Deps{
		DB:             dbPool,
		Transactions:   transactionsRepo,
		Wallets:        walletsRepo,
		Audit:          transactions.NewAuditRepository(dbPool),
		Categories:     categoriesRepo,
		Templates:      templatesRepo,
		Media:          mediaRepo,
		Clock:          clock.System{},
		ReportVersions: reportCache,
	})
	transactionsHandler := transactions.NewHandler(transactionsService)

	reportsService := reports.NewService(reports.Deps{
		Repo: reports.NewRepository(dbPool), Wallets: walletsRepo, Users: usersRepo, Clock: clock.System{},
		Cache: reportCache,
	})
	reportsHandler := reports.NewHandler(reportsService)

	exportService := export.NewService(export.Deps{
		Repo: export.NewRepository(dbPool), Store: objectStore, Users: usersRepo, Wallets: walletsRepo,
		Categories: categoriesRepo, Templates: templatesRepo, Transactions: transactionsRepo,
		AI: ai.NewRepository(dbPool), AIStreamWindow: cfg.AIStreamMaxDuration, AILocalWindow: cfg.AILocalMaxDuration,
	})
	exportHandler := export.NewHandler(exportService)

	aiHandler, err := newAIHandler(cfg, dbPool, redisClient, walletsRepo, usersRepo, rateLimiter, logger)
	if err != nil {
		return err
	}

	router.Group(func(r chi.Router) {
		r.Use(httpserver.Timeout(cfg.HTTPRequestTimeout))
		r.Use(auth.Middleware(cfg.JWTSigningKey))
		authHandler.MountProtected(r)
		authHandler.MountGoogleProtected(r)
		usersHandler.Mount(r)
		walletsHandler.Mount(r)
		exportHandler.Mount(r)
		transactionsHandler.Mount(r)
		categoriesHandler.Mount(r)
		templatesHandler.Mount(r)
		mediaHandler.Mount(r)
		reportsHandler.Mount(r)
		aiHandler.Mount(r)
	})
	// The AI analysis streams outlive the normal request timeout; they are
	// bounded by AI_STREAM_MAX_DURATION and the provider idle watchdog.
	router.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSigningKey))
		aiHandler.MountStreaming(r)
	})
	return nil
}

// newAIHandler wires the AI analysis (plan.md section 32). Without
// AI_KEY_ENCRYPTION_KEY the service has no secretbox and every AI route
// except GET /v1/ai/settings answers AI_DISABLED.
func newAIHandler(cfg config.Config, dbPool *database.Pool, redisClient *redis.Client, walletsRepo *wallets.Repository, usersRepo *users.Repository,
	rateLimiter *ratelimit.Limiter, logger *slog.Logger) (*ai.Handler, error) {
	var box *secretbox.Box
	if cfg.AIEnabled() {
		current, err := secretbox.ParseKey(cfg.AIKeyEncryptionKey)
		if err != nil {
			return nil, fmt.Errorf("AI_KEY_ENCRYPTION_KEY: %w", err)
		}
		var previous [][]byte
		if cfg.AIKeyEncryptionKeyPrevious != "" {
			old, err := secretbox.ParseKey(cfg.AIKeyEncryptionKeyPrevious)
			if err != nil {
				return nil, fmt.Errorf("AI_KEY_ENCRYPTION_KEY_PREVIOUS: %w", err)
			}
			previous = append(previous, old)
		}
		if box, err = secretbox.New(current, previous...); err != nil {
			return nil, err
		}
	}
	policy := provider.BaseURLPolicy{AllowPrivate: cfg.AIAllowPrivateBaseURLs, AllowedHosts: cfg.AIAllowedBaseURLHosts}
	service := ai.NewService(ai.Deps{
		DB:         dbPool,
		Locker:     ai.RedisLocker{Client: redisClient},
		Repo:       ai.NewRepository(dbPool),
		Wallets:    walletsRepo,
		Users:      usersRepo,
		Reports:    reports.NewRepository(dbPool),
		Categories: categories.NewRepository(dbPool),
		Limits: ai.Limits{
			MaxPromptTokens:   cfg.AIMaxPromptTokens,
			RunsPerHour:       cfg.AIRunsPerHour,
			StreamMaxDuration: cfg.AIStreamMaxDuration,
			OnDeviceEnabled:   cfg.AIOnDeviceEnabled,
			LocalRunsPerHour:  cfg.AILocalRunsPerHour,
			LocalMaxDuration:  cfg.AILocalMaxDuration,
		},
		Box:         box,
		Providers:   provider.NewHTTPFactory(policy, cfg.AIStreamIdleTimeout),
		Policy:      policy,
		RateLimiter: rateLimiter,
		Clock:       clock.System{},
		Logger:      logger,
	})
	return ai.NewHandler(service), nil
}
