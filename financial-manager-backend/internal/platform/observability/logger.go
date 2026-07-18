// Package observability wires up structured logging for the API and worker
// processes. It intentionally never logs secrets: callers must not pass
// passwords, tokens, or raw transaction descriptions as log attributes.
package observability

import (
	"log/slog"
	"os"

	"financial-manager-backend/internal/platform/config"
)

// NewLogger builds the process-wide structured logger. In production it
// emits JSON for machine ingestion; in local/test it emits human-readable
// text.
func NewLogger(cfg config.Config) *slog.Logger {
	level := slog.LevelInfo
	if cfg.AppEnv == config.EnvLocal {
		level = slog.LevelDebug
	}

	opts := &slog.HandlerOptions{Level: level}

	var handler slog.Handler
	if cfg.IsProduction() || cfg.AppEnv == config.EnvStaging {
		handler = slog.NewJSONHandler(os.Stdout, opts)
	} else {
		handler = slog.NewTextHandler(os.Stdout, opts)
	}

	logger := slog.New(handler).With(slog.String("env", cfg.AppEnv))
	return logger
}
