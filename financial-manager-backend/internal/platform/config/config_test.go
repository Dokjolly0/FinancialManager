package config

import (
	"strings"
	"testing"
	"time"
)

func clearEnv(t *testing.T) {
	t.Helper()
	for _, name := range []string{
		"APP_ENV", "HTTP_ADDR", "DATABASE_URL", "REDIS_ADDR", "REDIS_PASSWORD",
		"OBJECT_STORAGE_ENDPOINT", "OBJECT_STORAGE_BUCKET", "OBJECT_STORAGE_ACCESS_KEY",
		"OBJECT_STORAGE_SECRET_KEY", "OBJECT_STORAGE_USE_SSL", "GOOGLE_CLIENT_IDS",
		"JWT_SIGNING_KEY", "ACCESS_TOKEN_TTL", "REFRESH_TOKEN_TTL",
		"IMAGE_SEARCH_PROVIDER", "IMAGE_SEARCH_API_KEY", "MAX_UPLOAD_BYTES", "ALLOWED_IMAGE_TYPES",
		"BACKUP_ENABLED", "BACKUP_ENCRYPTION_KEY", "BACKUP_INTERVAL", "BACKUP_RETENTION_DAYS",
		"BACKUP_RETENTION_MONTHS", "BACKUP_INCLUDE_MEDIA", "BACKUP_GDRIVE_FOLDER_NAME",
		"GDRIVE_CLIENT_ID", "GDRIVE_CLIENT_SECRET", "GDRIVE_REFRESH_TOKEN",
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

func TestLoad_BackupDisabledByDefault(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.BackupEnabled {
		t.Error("expected backups to be disabled by default")
	}
	if cfg.BackupInterval != 24*time.Hour || cfg.BackupRetentionDays != 30 || cfg.BackupRetentionMonths != 12 {
		t.Errorf("unexpected backup defaults: interval=%v days=%d months=%d",
			cfg.BackupInterval, cfg.BackupRetentionDays, cfg.BackupRetentionMonths)
	}
	if !cfg.BackupIncludeMedia {
		t.Error("expected media to be included by default")
	}
}

func TestLoad_BackupEnabledRequiresCredentials(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("BACKUP_ENABLED", "true")

	_, err := Load()
	if err == nil {
		t.Fatal("expected error when BACKUP_ENABLED=true without encryption key and Drive credentials")
	}
	for _, want := range []string{"BACKUP_ENCRYPTION_KEY", "GDRIVE_REFRESH_TOKEN"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error %q does not mention %s", err, want)
		}
	}
}

func TestLoad_BackupEnabledWithCredentials(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("BACKUP_ENABLED", "true")
	t.Setenv("BACKUP_ENCRYPTION_KEY", "secret")
	t.Setenv("GDRIVE_CLIENT_ID", "id")
	t.Setenv("GDRIVE_CLIENT_SECRET", "client-secret")
	t.Setenv("GDRIVE_REFRESH_TOKEN", "refresh")
	t.Setenv("BACKUP_INTERVAL", "12h")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !cfg.BackupEnabled || cfg.BackupInterval != 12*time.Hour {
		t.Errorf("BackupEnabled=%v BackupInterval=%v", cfg.BackupEnabled, cfg.BackupInterval)
	}
}
