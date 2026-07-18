// Package httpserver builds the HTTP router shared by the API process: it
// wires cross-cutting middleware (request ID propagation, structured access
// logging, panic recovery) and the health endpoints. Feature modules mount
// their own routes on the returned router as they are implemented.
package httpserver

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
)

// New builds the base router with platform middleware and health endpoints
// mounted. Callers add feature routes under the returned router, typically
// grouped under "/v1".
func New(logger *slog.Logger, checks HealthChecks) chi.Router {
	r := chi.NewRouter()

	r.Use(chimiddleware.RequestID)
	// Intentionally no chi RealIP middleware: it blindly trusts
	// X-Forwarded-For/X-Real-IP, which lets a direct caller spoof its IP and
	// defeat per-IP rate limiting (plan.md section 19.5). Real-client-IP
	// resolution is added once the reverse proxy is in place, scoped to only
	// trust headers set by that specific proxy.
	r.Use(RequestLogger(logger))
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.Timeout(30 * time.Second))

	RegisterHealthRoutes(r, checks)

	return r
}

// RequestLogger logs one structured line per request: method, path, status,
// latency, and the correlation ID propagated from chi's RequestID
// middleware. It deliberately never logs request/response bodies, which may
// contain financial descriptions or secrets (plan.md section 19.7).
func RequestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)

			next.ServeHTTP(ww, r)

			logger.Info("http_request",
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.Int("status", ww.Status()),
				slog.Duration("duration", time.Since(start)),
				slog.String("request_id", chimiddleware.GetReqID(r.Context())),
			)
		})
	}
}
