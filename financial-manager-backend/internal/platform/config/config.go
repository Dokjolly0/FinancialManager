// Package config loads and validates process configuration from environment
// variables. All required settings are validated at startup so the process
// fails fast instead of surfacing missing configuration mid-request.
package config

import (
	"encoding/base64"
	"fmt"
	"net/netip"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration for the API and worker processes.
type Config struct {
	AppEnv   string
	HTTPAddr string

	// HTTPRequestTimeout bounds every route except the AI streaming ones,
	// which have their own limits below (plan.md section 32.4).
	HTTPRequestTimeout time.Duration

	// TrustedProxies are the reverse proxies whose X-Forwarded-For header
	// names the real client (TRUSTED_PROXY_CIDRS). Empty: the TCP peer is
	// the client, as when the API is reached directly.
	TrustedProxies []netip.Prefix

	// MetricsAddr is only used by the worker process (the API exposes
	// /metrics on HTTPAddr itself, alongside its regular routes).
	MetricsAddr string

	DatabaseURL string

	RedisAddr     string
	RedisPassword string

	ObjectStorageEndpoint  string
	ObjectStorageBucket    string
	ObjectStorageAccessKey string
	ObjectStorageSecretKey string
	ObjectStorageUseSSL    bool

	GoogleClientIDs []string

	JWTSigningKey   string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	ImageSearchProvider string
	ImageSearchAPIKey   string

	MaxUploadBytes    int64
	AllowedImageTypes []string

	// Backup settings are only read by the worker. When BackupEnabled is
	// false (the default outside production compose) the job never runs and
	// none of the Google Drive credentials are required.
	//
	// Unlike every other setting, a broken backup configuration doesn't fail
	// Load: it is reported in BackupProblems instead, so the worker can log
	// it and keep running its other jobs.
	BackupProblems         []string
	BackupEnabled          bool
	BackupEncryptionKey    string
	BackupInterval         time.Duration
	BackupRetentionDays    int
	BackupRetentionMonths  int
	BackupIncludeMedia     bool
	BackupGDriveFolderName string

	// Google Drive OAuth client ("Desktop app" type) and the refresh token
	// obtained once with cmd/gdrive-auth. A personal Gmail account cannot use
	// a service account here: service accounts have no My Drive quota.
	GDriveClientID     string
	GDriveClientSecret string
	GDriveRefreshToken string

	// AI analysis (plan.md section 32). AIKeyEncryptionKey is a base64
	// 32-byte key that encrypts the users' provider API keys at rest; when
	// it is empty the feature is unavailable but the server still starts.
	// AIKeyEncryptionKeyPrevious is only used to decrypt keys stored
	// before a rotation.
	AIKeyEncryptionKey         string
	AIKeyEncryptionKeyPrevious string
	// AIAllowPrivateBaseURLs lets an OpenAI-compatible base URL point at a
	// private or loopback address over plain http (a LAN Ollama server).
	// Off by default: on a server this is an SSRF hole.
	AIAllowPrivateBaseURLs bool
	// AIAllowedBaseURLHosts, when set, restricts OpenAI-compatible base
	// URLs to these exact hosts.
	AIAllowedBaseURLHosts []string
	AIStreamMaxDuration   time.Duration
	AIStreamIdleTimeout   time.Duration
	AIMaxPromptTokens     int
	AIRunsPerHour         int

	// On-device analysis (plan.md section 33): the model runs on the
	// phone, so no encryption key or provider is needed on the server.
	AIOnDeviceEnabled  bool
	AILocalRunsPerHour int
	AILocalMaxDuration time.Duration
}

const (
	EnvLocal      = "local"
	EnvTest       = "test"
	EnvStaging    = "staging"
	EnvProduction = "production"
)

// Load reads configuration from the environment and validates it. It returns
// every validation problem found, not just the first one, so a misconfigured
// deployment can be fixed in a single pass.
func Load() (Config, error) {
	var errs []string

	requireString := func(name string) string {
		v := os.Getenv(name)
		if v == "" {
			errs = append(errs, fmt.Sprintf("%s is required", name))
		}
		return v
	}

	optionalString := func(name, def string) string {
		v := os.Getenv(name)
		if v == "" {
			return def
		}
		return v
	}

	optionalDuration := func(name string, def time.Duration) time.Duration {
		v := os.Getenv(name)
		if v == "" {
			return def
		}
		d, err := time.ParseDuration(v)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s must be a valid duration (e.g. 15m): %v", name, err))
			return def
		}
		return d
	}

	optionalInt64 := func(name string, def int64) int64 {
		v := os.Getenv(name)
		if v == "" {
			return def
		}
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s must be an integer: %v", name, err))
			return def
		}
		return n
	}

	optionalBool := func(name string, def bool) bool {
		v := os.Getenv(name)
		if v == "" {
			return def
		}
		b, err := strconv.ParseBool(v)
		if err != nil {
			errs = append(errs, fmt.Sprintf("%s must be a boolean: %v", name, err))
			return def
		}
		return b
	}

	splitList := func(name string) []string {
		v := os.Getenv(name)
		if v == "" {
			return nil
		}
		parts := strings.Split(v, ",")
		out := make([]string, 0, len(parts))
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" {
				out = append(out, p)
			}
		}
		return out
	}

	parsePrefixes := func(name string) []netip.Prefix {
		var out []netip.Prefix
		for _, e := range splitList(name) {
			if p, err := netip.ParsePrefix(e); err == nil {
				out = append(out, p.Masked())
			} else if addr, err := netip.ParseAddr(e); err == nil {
				out = append(out, netip.PrefixFrom(addr, addr.BitLen()))
			} else {
				errs = append(errs, fmt.Sprintf("%s: %q is not a CIDR or IP address", name, e))
			}
		}
		return out
	}

	cfg := Config{
		AppEnv:   optionalString("APP_ENV", EnvLocal),
		HTTPAddr: optionalString("HTTP_ADDR", ":8080"),

		HTTPRequestTimeout: optionalDuration("HTTP_REQUEST_TIMEOUT", 30*time.Second),
		TrustedProxies:     parsePrefixes("TRUSTED_PROXY_CIDRS"),
		MetricsAddr:        optionalString("METRICS_ADDR", ":9101"),

		DatabaseURL: requireString("DATABASE_URL"),

		RedisAddr:     optionalString("REDIS_ADDR", "localhost:6379"),
		RedisPassword: os.Getenv("REDIS_PASSWORD"),

		ObjectStorageEndpoint:  optionalString("OBJECT_STORAGE_ENDPOINT", "localhost:10004"),
		ObjectStorageBucket:    optionalString("OBJECT_STORAGE_BUCKET", "financial-manager-media"),
		ObjectStorageAccessKey: os.Getenv("OBJECT_STORAGE_ACCESS_KEY"),
		ObjectStorageSecretKey: os.Getenv("OBJECT_STORAGE_SECRET_KEY"),
		ObjectStorageUseSSL:    optionalBool("OBJECT_STORAGE_USE_SSL", false),

		GoogleClientIDs: splitList("GOOGLE_CLIENT_IDS"),

		JWTSigningKey:   os.Getenv("JWT_SIGNING_KEY"),
		AccessTokenTTL:  optionalDuration("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL: optionalDuration("REFRESH_TOKEN_TTL", 30*24*time.Hour),

		ImageSearchProvider: optionalString("IMAGE_SEARCH_PROVIDER", "stub"),
		ImageSearchAPIKey:   os.Getenv("IMAGE_SEARCH_API_KEY"),

		MaxUploadBytes:    optionalInt64("MAX_UPLOAD_BYTES", 10*1024*1024),
		AllowedImageTypes: splitList("ALLOWED_IMAGE_TYPES"),

		AIKeyEncryptionKey:         os.Getenv("AI_KEY_ENCRYPTION_KEY"),
		AIKeyEncryptionKeyPrevious: os.Getenv("AI_KEY_ENCRYPTION_KEY_PREVIOUS"),
		AIAllowPrivateBaseURLs:     optionalBool("AI_ALLOW_PRIVATE_BASE_URLS", false),
		AIAllowedBaseURLHosts:      splitList("AI_ALLOWED_BASE_URL_HOSTS"),
		AIStreamMaxDuration:        optionalDuration("AI_STREAM_MAX_DURATION", 5*time.Minute),
		AIStreamIdleTimeout:        optionalDuration("AI_STREAM_IDLE_TIMEOUT", 90*time.Second),
		AIMaxPromptTokens:          int(optionalInt64("AI_MAX_PROMPT_TOKENS", 60000)),
		AIRunsPerHour:              int(optionalInt64("AI_RUNS_PER_HOUR", 20)),
		AIOnDeviceEnabled:          optionalBool("AI_ON_DEVICE_ENABLED", true),
		AILocalRunsPerHour:         int(optionalInt64("AI_LOCAL_RUNS_PER_HOUR", 30)),
		AILocalMaxDuration:         optionalDuration("AI_LOCAL_MAX_DURATION", 30*time.Minute),
	}

	// Backup settings are parsed with errs swapped out, so their parse
	// errors land in BackupProblems rather than failing the whole config.
	mainErrs := errs
	errs = nil
	cfg.BackupEnabled = optionalBool("BACKUP_ENABLED", false)
	cfg.BackupEncryptionKey = os.Getenv("BACKUP_ENCRYPTION_KEY")
	cfg.BackupInterval = optionalDuration("BACKUP_INTERVAL", 24*time.Hour)
	cfg.BackupRetentionDays = int(optionalInt64("BACKUP_RETENTION_DAYS", 30))
	cfg.BackupRetentionMonths = int(optionalInt64("BACKUP_RETENTION_MONTHS", 12))
	cfg.BackupIncludeMedia = optionalBool("BACKUP_INCLUDE_MEDIA", true)
	cfg.BackupGDriveFolderName = optionalString("BACKUP_GDRIVE_FOLDER_NAME", "FinancialManager Backups")
	cfg.GDriveClientID = os.Getenv("GDRIVE_CLIENT_ID")
	cfg.GDriveClientSecret = os.Getenv("GDRIVE_CLIENT_SECRET")
	cfg.GDriveRefreshToken = os.Getenv("GDRIVE_REFRESH_TOKEN")
	if cfg.BackupEnabled {
		// Backups land on a third-party service, so they are never uploaded
		// unencrypted, in any environment.
		if cfg.BackupEncryptionKey == "" {
			errs = append(errs, "BACKUP_ENCRYPTION_KEY is required when BACKUP_ENABLED=true")
		}
		if cfg.GDriveClientID == "" || cfg.GDriveClientSecret == "" || cfg.GDriveRefreshToken == "" {
			errs = append(errs, "GDRIVE_CLIENT_ID, GDRIVE_CLIENT_SECRET and GDRIVE_REFRESH_TOKEN are required when BACKUP_ENABLED=true (see docs/backup-restore.md)")
		}
		if cfg.BackupInterval < time.Minute {
			errs = append(errs, "BACKUP_INTERVAL must be at least 1m")
		}
		if cfg.BackupRetentionDays < 1 {
			errs = append(errs, "BACKUP_RETENTION_DAYS must be at least 1")
		}
		if cfg.BackupRetentionMonths < 0 {
			errs = append(errs, "BACKUP_RETENTION_MONTHS must not be negative")
		}
	}
	cfg.BackupProblems = errs
	errs = mainErrs

	if len(cfg.AllowedImageTypes) == 0 {
		cfg.AllowedImageTypes = []string{"image/jpeg", "image/png", "image/webp"}
	}

	switch cfg.AppEnv {
	case EnvLocal, EnvTest, EnvStaging, EnvProduction:
	default:
		errs = append(errs, fmt.Sprintf("APP_ENV must be one of local/test/staging/production, got %q", cfg.AppEnv))
	}

	if cfg.AppEnv == EnvProduction {
		if cfg.JWTSigningKey == "" {
			errs = append(errs, "JWT_SIGNING_KEY is required in production")
		}
		if cfg.ObjectStorageAccessKey == "" || cfg.ObjectStorageSecretKey == "" {
			errs = append(errs, "OBJECT_STORAGE_ACCESS_KEY and OBJECT_STORAGE_SECRET_KEY are required in production")
		}
	} else if cfg.JWTSigningKey == "" {
		// Deterministic dev-only default so local/test runs do not need a secret manager.
		cfg.JWTSigningKey = "dev-only-insecure-signing-key-do-not-use-in-production"
	}

	if cfg.ImageSearchProvider == "unsplash" && cfg.ImageSearchAPIKey == "" {
		errs = append(errs, "IMAGE_SEARCH_API_KEY is required when IMAGE_SEARCH_PROVIDER=unsplash")
	}

	if cfg.MaxUploadBytes <= 0 {
		errs = append(errs, "MAX_UPLOAD_BYTES must be greater than zero")
	}

	if cfg.HTTPRequestTimeout <= 0 {
		errs = append(errs, "HTTP_REQUEST_TIMEOUT must be greater than zero")
	}

	// A missing AI key only disables the feature, but a malformed one is a
	// typo worth failing fast on: silently disabling would hide it.
	for name, v := range map[string]string{
		"AI_KEY_ENCRYPTION_KEY":          cfg.AIKeyEncryptionKey,
		"AI_KEY_ENCRYPTION_KEY_PREVIOUS": cfg.AIKeyEncryptionKeyPrevious,
	} {
		if v == "" {
			continue
		}
		if key, err := base64.StdEncoding.DecodeString(v); err != nil || len(key) != 32 {
			errs = append(errs, fmt.Sprintf("%s must be 32 bytes encoded as standard base64 (openssl rand -base64 32)", name))
		}
	}
	if cfg.AIKeyEncryptionKeyPrevious != "" && cfg.AIKeyEncryptionKey == "" {
		errs = append(errs, "AI_KEY_ENCRYPTION_KEY_PREVIOUS requires AI_KEY_ENCRYPTION_KEY")
	}
	if cfg.AIStreamMaxDuration < 10*time.Second {
		errs = append(errs, "AI_STREAM_MAX_DURATION must be at least 10s")
	}
	if cfg.AIStreamIdleTimeout < time.Second || cfg.AIStreamIdleTimeout > cfg.AIStreamMaxDuration {
		errs = append(errs, "AI_STREAM_IDLE_TIMEOUT must be between 1s and AI_STREAM_MAX_DURATION")
	}
	if cfg.AIMaxPromptTokens < 1000 {
		errs = append(errs, "AI_MAX_PROMPT_TOKENS must be at least 1000")
	}
	if cfg.AIRunsPerHour < 1 {
		errs = append(errs, "AI_RUNS_PER_HOUR must be at least 1")
	}
	if cfg.AILocalRunsPerHour < 1 {
		errs = append(errs, "AI_LOCAL_RUNS_PER_HOUR must be at least 1")
	}
	if cfg.AILocalMaxDuration < time.Minute {
		errs = append(errs, "AI_LOCAL_MAX_DURATION must be at least 1m")
	}

	if len(errs) > 0 {
		return Config{}, fmt.Errorf("invalid configuration:\n  - %s", strings.Join(errs, "\n  - "))
	}

	return cfg, nil
}

// AIEnabled reports whether the AI analysis feature can run, i.e. whether
// there is a key to encrypt the users' provider API keys with.
func (c Config) AIEnabled() bool {
	return c.AIKeyEncryptionKey != ""
}

// IsProduction reports whether the process is running in the production environment.
func (c Config) IsProduction() bool {
	return c.AppEnv == EnvProduction
}
