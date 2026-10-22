package ai_test

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/httpserver"
	"financial-manager-backend/internal/platform/reqctx"
	"financial-manager-backend/internal/platform/secretbox"
	"financial-manager-backend/internal/reports"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// harness serves the AI routes for one fresh user through a real router,
// with a scripted provider standing in for the LLM.
type harness struct {
	t        *testing.T
	db       *database.Pool
	repo     *ai.Repository
	wallets  *wallets.Repository
	userID   uuid.UUID
	walletID uuid.UUID
	box      *secretbox.Box
	fake     *provider.ScriptedProvider
	factory  *provider.StaticFactory
	service  *ai.Service
	server   *httptest.Server
	now      time.Time
}

type harnessOptions struct {
	disabled        bool
	maxPromptTokens int
	// requestTimeout, when set, wraps the JSON routes in the platform
	// timeout as cmd/api does, leaving the streaming routes outside it.
	requestTimeout time.Duration
	// onDevice enables on-device analyses.
	onDevice bool
	// clockOffset, when set, makes the service clock the real time plus
	// *clockOffset (database timestamps are real time), so tests can move
	// time forward.
	clockOffset *time.Duration
}

// offsetClock is the real time shifted by a mutable offset.
type offsetClock struct{ offset *time.Duration }

func (c offsetClock) Now() time.Time { return time.Now().Add(*c.offset) }

func newHarness(t *testing.T, opts ...harnessOptions) *harness {
	t.Helper()
	var opt harnessOptions
	if len(opts) > 0 {
		opt = opts[0]
	}
	databaseURL := envOrDefault("TEST_DATABASE_URL", "postgres://financial_manager:financial_manager@localhost:10001/financial_manager?sslmode=disable")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	dbPool, err := database.Connect(ctx, databaseURL)
	if err != nil {
		t.Skipf("skipping: dev Postgres not reachable at %s: %v", databaseURL, err)
	}
	t.Cleanup(dbPool.Close)

	usersRepo := users.NewRepository(dbPool)
	walletsRepo := wallets.NewRepository(dbPool)
	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName: "Ai", LastName: "Test", Username: "aitest" + suffix, Email: "aitest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B", AvatarTextColor: "#FFFFFF", Locale: "it-IT", Timezone: "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	wallet, err := walletsRepo.Create(context.Background(), wallets.CreateRowInput{
		UserID: user.ID, Name: "Conto", Currency: "EUR", Type: wallets.TypeBank, Icon: "bank", Color: "#6750A4",
	})
	if err != nil {
		t.Fatalf("create wallet: %v", err)
	}

	h := &harness{
		t: t, db: dbPool, repo: ai.NewRepository(dbPool), wallets: walletsRepo, userID: user.ID, walletID: wallet.ID,
		fake: &provider.ScriptedProvider{}, now: time.Date(2026, 10, 20, 10, 0, 0, 0, time.UTC),
	}
	h.factory = &provider.StaticFactory{Provider: h.fake}
	if !opt.disabled {
		key := make([]byte, secretbox.KeySize)
		_, _ = rand.Read(key)
		h.box, _ = secretbox.New(key)
	}
	var serviceClock clock.Clock = clock.Frozen{At: h.now}
	if opt.clockOffset != nil {
		serviceClock = offsetClock{offset: opt.clockOffset}
	}
	h.service = ai.NewService(ai.Deps{
		DB: dbPool, Repo: h.repo, Wallets: walletsRepo, Users: usersRepo, Reports: reports.NewRepository(dbPool),
		Categories: categories.NewRepository(dbPool),
		Limits:     ai.Limits{MaxPromptTokens: opt.maxPromptTokens, OnDeviceEnabled: opt.onDevice},
		Box:        h.box, Providers: h.factory,
		Policy: provider.BaseURLPolicy{}, Clock: serviceClock,
	})

	router := chi.NewRouter()
	router.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			next.ServeHTTP(w, r.WithContext(reqctx.WithUser(r.Context(), h.userID, uuid.New())))
		})
	})
	handler := ai.NewHandler(h.service)
	router.Group(func(r chi.Router) {
		if opt.requestTimeout > 0 {
			r.Use(httpserver.Timeout(opt.requestTimeout))
		}
		handler.Mount(r)
	})
	handler.MountStreaming(router)
	h.server = httptest.NewServer(router)
	t.Cleanup(h.server.Close)
	return h
}

type response struct {
	status int
	raw    string
	body   map[string]any
}

func (h *harness) do(method, path string, body any) response {
	h.t.Helper()
	var reader io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reader = bytes.NewReader(b)
	}
	req, _ := http.NewRequest(method, h.server.URL+path, reader)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		h.t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := response{status: resp.StatusCode, raw: string(raw)}
	_ = json.Unmarshal(raw, &out.body)
	return out
}

func (r response) errorCode() string {
	e, _ := r.body["error"].(map[string]any)
	code, _ := e["code"].(string)
	return code
}

func (r response) fieldError(field string) string {
	e, _ := r.body["error"].(map[string]any)
	fields, _ := e["field_errors"].(map[string]any)
	code, _ := fields[field].(string)
	return code
}

func (h *harness) mustStatus(r response, want int) {
	h.t.Helper()
	if r.status != want {
		h.t.Fatalf("status = %d, want %d: %s", r.status, want, r.raw)
	}
}

// configure saves an OpenAI configuration with key and model, and accepts
// the consent, as a user finishing setup would.
func (h *harness) configure(key string) map[string]any {
	h.t.Helper()
	r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "openai", "model": "gpt-test", "api_key": key, "max_output_tokens": 2048, "version": 0,
	})
	h.mustStatus(r, http.StatusOK)
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": ai.ConsentVersion}), http.StatusNoContent)
	return r.body
}
