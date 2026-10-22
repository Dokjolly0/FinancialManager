package httpserver

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORS(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
	})
	allowed := CORS([]string{"http://localhost:5000/"})(ok)

	do := func(h http.Handler, method, origin string, preflight bool) *httptest.ResponseRecorder {
		t.Helper()
		req := httptest.NewRequest(method, "/v1/me", nil)
		if origin != "" {
			req.Header.Set("Origin", origin)
		}
		if preflight {
			req.Header.Set("Access-Control-Request-Method", "POST")
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}

	t.Run("allowed origin gets the header", func(t *testing.T) {
		rec := do(allowed, http.MethodGet, "http://localhost:5000", false)
		if rec.Code != http.StatusTeapot {
			t.Fatalf("status = %d, want the handler's", rec.Code)
		}
		if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5000" {
			t.Fatalf("Allow-Origin = %q", got)
		}
		if rec.Header().Get("Access-Control-Allow-Credentials") != "" {
			t.Fatal("credentials must not be allowed")
		}
	})

	t.Run("preflight is answered without reaching the handler", func(t *testing.T) {
		rec := do(allowed, http.MethodOptions, "http://localhost:5000", true)
		if rec.Code != http.StatusNoContent {
			t.Fatalf("status = %d, want 204", rec.Code)
		}
		if rec.Header().Get("Access-Control-Allow-Headers") == "" {
			t.Fatal("missing Allow-Headers")
		}
	})

	t.Run("other origins get nothing", func(t *testing.T) {
		rec := do(allowed, http.MethodOptions, "https://evil.example", true)
		if rec.Code != http.StatusTeapot || rec.Header().Get("Access-Control-Allow-Origin") != "" {
			t.Fatalf("status %d, headers %v", rec.Code, rec.Header())
		}
	})

	t.Run("no origins configured: a no-op", func(t *testing.T) {
		rec := do(CORS(nil)(ok), http.MethodGet, "http://localhost:5000", false)
		if rec.Header().Get("Access-Control-Allow-Origin") != "" {
			t.Fatal("unexpected CORS header")
		}
	})
}
