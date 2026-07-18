package httpserver

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
)

// HealthChecks holds the dependency pings used to answer readiness probes.
// Any field may be nil, in which case that dependency is not checked (useful
// for the worker process, which may not need every dependency).
type HealthChecks struct {
	Database func(ctx context.Context) error
	Redis    func(ctx context.Context) error
}

// RegisterHealthRoutes mounts /health/live and /health/ready.
//
// live reports whether the process itself is running and answers requests;
// it must never depend on external services, or a database outage would
// cause the orchestrator to kill healthy processes.
//
// ready reports whether the process can currently serve real traffic. Per
// plan.md section 21.7, PostgreSQL is mandatory for readiness; Redis may be
// degraded depending on which features are affected, but for the MVP we
// treat it as required since rate limiting protects auth endpoints.
func RegisterHealthRoutes(r chi.Router, checks HealthChecks) {
	r.Get("/health/live", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "live"})
	})

	r.Get("/health/ready", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()

		problems := map[string]string{}

		if checks.Database != nil {
			if err := checks.Database(ctx); err != nil {
				problems["database"] = err.Error()
			}
		}
		if checks.Redis != nil {
			if err := checks.Redis(ctx); err != nil {
				problems["redis"] = err.Error()
			}
		}

		if len(problems) > 0 {
			writeJSON(w, http.StatusServiceUnavailable, map[string]any{
				"status":   "not_ready",
				"problems": problems,
			})
			return
		}

		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
