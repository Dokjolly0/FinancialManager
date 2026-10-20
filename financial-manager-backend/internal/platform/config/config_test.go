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
		"HTTP_REQUEST_TIMEOUT", "AI_KEY_ENCRYPTION_KEY", "AI_KEY_ENCRYPTION_KEY_PREVIOUS",
		"AI_ALLOW_PRIVATE_BASE_URLS", "AI_ALLOWED_BASE_URL_HOSTS", "AI_STREAM_MAX_DURATION",
		"AI_STREAM_IDLE_TIMEOUT", "AI_MAX_PROMPT_TOKENS", "AI_RUNS_PER_HOUR",
		"AI_ON_DEVICE_ENABLED", "AI_LOCAL_RUNS_PER_HOUR", "AI_LOCAL_MAX_DURATION",
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

// A broken backup configuration must not stop the process: it's reported
// in BackupProblems so the worker can log it and keep its other jobs going.
func TestLoad_BackupMissingCredentialsIsNotFatal(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("APP_ENV", EnvProduction)
	t.Setenv("JWT_SIGNING_KEY", "k")
	t.Setenv("OBJECT_STORAGE_ACCESS_KEY", "a")
	t.Setenv("OBJECT_STORAGE_SECRET_KEY", "s")
	t.Setenv("BACKUP_ENABLED", "true")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	problems := strings.Join(cfg.BackupProblems, "\n")
	for _, want := range []string{"BACKUP_ENCRYPTION_KEY", "GDRIVE_REFRESH_TOKEN"} {
		if !strings.Contains(problems, want) {
			t.Errorf("BackupProblems %q does not mention %s", problems, want)
		}
	}
}

func TestLoad_MalformedBackupSettingIsNotFatal(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("BACKUP_INTERVAL", "every day")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(cfg.BackupProblems) != 1 || !strings.Contains(cfg.BackupProblems[0], "BACKUP_INTERVAL") {
		t.Errorf("BackupProblems = %q", cfg.BackupProblems)
	}
}

// Swapping errs while parsing backup settings must not drop the errors
// collected before it.
func TestLoad_MainErrorsSurviveBackupParsing(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("ACCESS_TOKEN_TTL", "soon")
	t.Setenv("BACKUP_ENABLED", "true")

	if _, err := Load(); err == nil || !strings.Contains(err.Error(), "ACCESS_TOKEN_TTL") {
		t.Fatalf("expected ACCESS_TOKEN_TTL error, got %v", err)
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
	if !cfg.BackupEnabled || cfg.BackupInterval != 12*time.Hour || len(cfg.BackupProblems) != 0 {
		t.Errorf("BackupEnabled=%v BackupInterval=%v BackupProblems=%q",
			cfg.BackupEnabled, cfg.BackupInterval, cfg.BackupProblems)
	}
}

func TestLoad_AIDisabledByDefault(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.AIEnabled() {
		t.Error("AIEnabled() = true without AI_KEY_ENCRYPTION_KEY")
	}
	if cfg.HTTPRequestTimeout != 30*time.Second || cfg.AIStreamMaxDuration != 5*time.Minute ||
		cfg.AIStreamIdleTimeout != 90*time.Second || cfg.AIMaxPromptTokens != 60000 || cfg.AIRunsPerHour != 20 {
		t.Errorf("unexpected defaults: %+v", cfg)
	}
	if cfg.AIAllowPrivateBaseURLs {
		t.Error("AIAllowPrivateBaseURLs must default to false")
	}
	if !cfg.AIOnDeviceEnabled || cfg.AILocalRunsPerHour != 30 || cfg.AILocalMaxDuration != 30*time.Minute {
		t.Errorf("on-device defaults: %v %d %v", cfg.AIOnDeviceEnabled, cfg.AILocalRunsPerHour, cfg.AILocalMaxDuration)
	}
}

func TestLoad_AIEnabledWithValidKey(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://localhost/test")
	t.Setenv("AI_KEY_ENCRYPTION_KEY", "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=")
	t.Setenv("AI_ALLOWED_BASE_URL_HOSTS", "api.mistral.ai, openrouter.ai")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !cfg.AIEnabled() {
		t.Error("AIEnabled() = false with a valid key")
	}
	if len(cfg.AIAllowedBaseURLHosts) != 2 || cfg.AIAllowedBaseURLHosts[1] != "openrouter.ai" {
		t.Errorf("AIAllowedBaseURLHosts = %q", cfg.AIAllowedBaseURLHosts)
	}
}

func TestLoad_AIInvalidSettings(t *testing.T) {
	cases := map[string]map[string]string{
		"key not base64":       {"AI_KEY_ENCRYPTION_KEY": "not base64!"},
		"key wrong length":     {"AI_KEY_ENCRYPTION_KEY": "c2hvcnQ="},
		"previous without key": {"AI_KEY_ENCRYPTION_KEY_PREVIOUS": "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="},
		"idle above max":       {"AI_STREAM_MAX_DURATION": "1m", "AI_STREAM_IDLE_TIMEOUT": "2m"},
		"zero runs per hour":   {"AI_RUNS_PER_HOUR": "0"},
		"zero request timeout": {"HTTP_REQUEST_TIMEOUT": "0s"},
		"zero local runs":      {"AI_LOCAL_RUNS_PER_HOUR": "0"},
		"short local duration": {"AI_LOCAL_MAX_DURATION": "10s"},
	}
	for name, env := range cases {
		t.Run(name, func(t *testing.T) {
			clearEnv(t)
			t.Setenv("DATABASE_URL", "postgres://localhost/test")
			for k, v := range env {
				t.Setenv(k, v)
			}
			if _, err := Load(); err == nil {
				t.Fatal("expected a configuration error")
			}
		})
	}
}
