// Package config loads and validates process configuration from environment
// variables. All required settings are validated at startup so the process
// fails fast instead of surfacing missing configuration mid-request.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration for the API and worker processes.
type Config struct {
	AppEnv   string
	HTTPAddr string

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

	cfg := Config{
		AppEnv:   optionalString("APP_ENV", EnvLocal),
		HTTPAddr: optionalString("HTTP_ADDR", ":8080"),

		DatabaseURL: requireString("DATABASE_URL"),

		RedisAddr:     optionalString("REDIS_ADDR", "localhost:6379"),
		RedisPassword: os.Getenv("REDIS_PASSWORD"),

		ObjectStorageEndpoint:  optionalString("OBJECT_STORAGE_ENDPOINT", "localhost:9000"),
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
	}

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

	if len(errs) > 0 {
		return Config{}, fmt.Errorf("invalid configuration:\n  - %s", strings.Join(errs, "\n  - "))
	}

	return cfg, nil
}

// IsProduction reports whether the process is running in the production environment.
func (c Config) IsProduction() bool {
	return c.AppEnv == EnvProduction
}
