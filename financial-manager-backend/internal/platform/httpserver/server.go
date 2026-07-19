// Package httpserver builds the HTTP router shared by the API process: it
// wires cross-cutting middleware (request ID propagation, structured access
// logging, panic recovery) and the health endpoints. Feature modules mount
// their own routes on the returned router as they are implemented.
package httpserver

import (
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"

	"financial-manager-backend/internal/platform/metrics"
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
	r.Use(MetricsMiddleware)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.Timeout(30 * time.Second))

	RegisterHealthRoutes(r, checks)
	// Unauthenticated by design — a Prometheus scraper has no access
	// token, and this endpoint exposes only aggregate counts/latencies,
	// never per-user or financial data (plan.md section 22.1). In
	// production it must still only be reachable from the scraper's
	// network, not the public internet.
	r.Handle("/metrics", metrics.Handler())

	return r
}

// MetricsMiddleware records plan.md section 22.1's "richieste per
// endpoint/status" and "latenza p50/p95/p99". It reads the matched route
// pattern (e.g. "/v1/transactions/{id}", not the literal path with real
// IDs in it) after the handler runs, once chi has populated it, so the
// requests-per-endpoint metric stays low-cardinality regardless of how
// many distinct IDs are ever requested.
func MetricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)

		next.ServeHTTP(ww, r)

		route := chi.RouteContext(r.Context()).RoutePattern()
		if route == "" {
			route = "unmatched"
		}
		metrics.HTTPRequestsTotal.WithLabelValues(r.Method, route, strconv.Itoa(ww.Status())).Inc()
		metrics.HTTPRequestDuration.WithLabelValues(r.Method, route).Observe(time.Since(start).Seconds())
	})
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
