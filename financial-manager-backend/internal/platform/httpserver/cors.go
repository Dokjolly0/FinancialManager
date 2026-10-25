package httpserver

import (
	"net/http"
	"strings"
)

// CORS lets a browser app on another origin call the API. Normally
// allowedOrigins is empty and no CORS header is ever sent: in production the
// dashboard and the API share an origin (financialmanager.alexviolatto.dev
// and /api), and in development the dashboard's dev server
// (financial-manager-web, port 5000) proxies /api to the API. It is only for
// a client served from somewhere else.
//
// Only exact origins are allowed (no wildcard) and no credentials: the app
// authenticates with a bearer token, not cookies.
func CORS(allowedOrigins []string) func(http.Handler) http.Handler {
	allowed := make(map[string]bool, len(allowedOrigins))
	for _, o := range allowedOrigins {
		allowed[strings.TrimSuffix(o, "/")] = true
	}

	return func(next http.Handler) http.Handler {
		if len(allowed) == 0 {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			if origin == "" || !allowed[origin] {
				next.ServeHTTP(w, r)
				return
			}
			h := w.Header()
			h.Add("Vary", "Origin")
			h.Set("Access-Control-Allow-Origin", origin)
			h.Set("Access-Control-Expose-Headers", "X-Request-Id, Content-Disposition")

			// Preflight: answer it here, before auth and routing.
			if r.Method == http.MethodOptions && r.Header.Get("Access-Control-Request-Method") != "" {
				h.Add("Vary", "Access-Control-Request-Method")
				h.Add("Vary", "Access-Control-Request-Headers")
				h.Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE")
				h.Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept, Idempotency-Key, X-Request-Id")
				h.Set("Access-Control-Max-Age", "600")
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
