package config

import (
	"testing"
)

func clearEnv(t *testing.T) {
	t.Helper()
	for _, name := range []string{
		"APP_ENV", "HTTP_ADDR", "DATABASE_URL", "REDIS_ADDR", "REDIS_PASSWORD",
		"OBJECT_STORAGE_ENDPOINT", "OBJECT_STORAGE_BUCKET", "OBJECT_STORAGE_ACCESS_KEY",
		"OBJECT_STORAGE_SECRET_KEY", "OBJECT_STORAGE_USE_SSL", "GOOGLE_CLIENT_IDS",
		"JWT_SIGNING_KEY", "ACCESS_TOKEN_TTL", "REFRESH_TOKEN_TTL",
		"IMAGE_SEARCH_PROVIDER", "IMAGE_SEARCH_API_KEY", "MAX_UPLOAD_BYTES", "ALLOWED_IMAGE_TYPES",
	} {
		t.Setenv(name, "")
	}
}

func TestLoad_MissingRequiredDatabaseURL(t *testing.T) {
	clearEnv(t)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error when DATABASE_URL is missing, got nil")
	}
}

func TestLoad_DefaultsAppliedInLocal(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.AppEnv != EnvLocal {
		t.Errorf("AppEnv = %q, want %q", cfg.AppEnv, EnvLocal)
	}
	if cfg.JWTSigningKey == "" {
		t.Error("expected a dev-only JWT signing key default in local env")
	}
	if len(cfg.AllowedImageTypes) == 0 {
		t.Error("expected default allowed image types")
	}
	if cfg.MaxUploadBytes <= 0 {
		t.Error("expected positive default MaxUploadBytes")
	}
}

func TestLoad_ProductionRequiresSecrets(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("APP_ENV", EnvProduction)

	_, err := Load()
	if err == nil {
		t.Fatal("expected error when production is missing JWT_SIGNING_KEY and object storage credentials")
	}
}

func TestLoad_UnsplashRequiresAPIKey(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("IMAGE_SEARCH_PROVIDER", "unsplash")

	_, err := Load()
	if err == nil {
		t.Fatal("expected error when IMAGE_SEARCH_PROVIDER=unsplash without IMAGE_SEARCH_API_KEY")
	}
}

func TestLoad_InvalidAppEnvRejected(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("APP_ENV", "not-a-real-env")

	_, err := Load()
	if err == nil {
		t.Fatal("expected error for invalid APP_ENV")
	}
}
