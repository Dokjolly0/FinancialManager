package httpserver

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

// slowHandler answers after d unless the request context ends first, the
// way a well-behaved handler reacts to the Timeout middleware.
func slowHandler(d time.Duration) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-time.After(d):
			_, _ = io.WriteString(w, "done")
		case <-r.Context().Done():
		}
	}
}

// The request timeout must only apply to the groups that opt in, so the AI
// analysis streams (plan.md section 32.4) can outlive it.
func TestNew_TimeoutAppliesOnlyToOptInGroups(t *testing.T) {
	const timeout = 50 * time.Millisecond
	checks := HealthChecks{
		Database: func(context.Context) error { return nil },
		Redis:    func(context.Context) error { return nil },
	}
	router := New(slog.New(slog.NewTextHandler(io.Discard, nil)), checks, timeout, nil)

	router.Group(func(r chi.Router) {
		r.Use(Timeout(timeout))
		r.Get("/bounded", slowHandler(4*timeout))
	})
	router.Get("/streaming", slowHandler(4*timeout))

	server := httptest.NewServer(router)
	defer server.Close()

	get := func(path string) (int, string) {
		t.Helper()
		resp, err := http.Get(server.URL + path)
		if err != nil {
			t.Fatalf("GET %s: %v", path, err)
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, string(body)
	}

	if status, _ := get("/bounded"); status != http.StatusGatewayTimeout {
		t.Fatalf("/bounded status = %d, want 504", status)
	}
	if status, body := get("/streaming"); status != http.StatusOK || body != "done" {
		t.Fatalf("/streaming = %d %q, want 200 \"done\"", status, body)
	}
	if status, _ := get("/health/live"); status != http.StatusOK {
		t.Fatalf("/health/live status = %d, want 200", status)
	}
}
