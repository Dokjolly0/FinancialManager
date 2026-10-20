package ai_test

import (
	"context"
	"net/http"
	"strings"
	"testing"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/provider"
)

func TestSettings_DisabledWithoutEncryptionKey(t *testing.T) {
	h := newHarness(t, harnessOptions{disabled: true})

	r := h.do(http.MethodGet, "/v1/ai/settings", nil)
	h.mustStatus(r, http.StatusOK)
	if r.body["available"] != false {
		t.Fatalf("available = %v, want false", r.body["available"])
	}
	for _, call := range []struct{ method, path string }{
		{http.MethodPut, "/v1/ai/settings"}, {http.MethodGet, "/v1/ai/context"},
		{http.MethodPut, "/v1/ai/consent"}, {http.MethodPost, "/v1/ai/settings/test"},
	} {
		r := h.do(call.method, call.path, map[string]any{"provider": "openai", "consent_version": 1})
		if r.status != http.StatusServiceUnavailable || r.errorCode() != "AI_DISABLED" {
			t.Errorf("%s %s = %d %s, want 503 AI_DISABLED", call.method, call.path, r.status, r.errorCode())
		}
	}
}

func TestSettings_KeyIsEncryptedAndNeverReturned(t *testing.T) {
	h := newHarness(t)
	const key = "sk-proj-SuperSecretValue1234"

	r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "openai", "model": " gpt-test ", "api_key": key, "max_output_tokens": 2048,
		"input_price_per_mtok": 1.25, "defaults": map[string]any{"anonymize_titles": true}, "version": 0,
	})
	h.mustStatus(r, http.StatusOK)
	if strings.Contains(r.raw, key) || strings.Contains(r.raw, "SuperSecret") {
		t.Fatalf("response leaks the key: %s", r.raw)
	}
	active, _ := r.body["active"].(map[string]any)
	if active == nil || active["key_hint"] != "sk-…1234" || active["has_key"] != true || active["model"] != "gpt-test" {
		t.Fatalf("active = %v", active)
	}
	if r.body["version"] != float64(1) || r.body["input_price_per_mtok"] != 1.25 {
		t.Fatalf("version/price = %v/%v", r.body["version"], r.body["input_price_per_mtok"])
	}
	setup := r.body["setup"].(map[string]any)
	if setup["has_provider"] != true || setup["has_model"] != true || setup["wallets_total"] != float64(1) {
		t.Fatalf("setup = %v", setup)
	}
	if consent := r.body["consent"].(map[string]any); consent["required"] != true {
		t.Fatalf("consent = %v, want required", consent)
	}

	// At rest: only ciphertext, bound to this user/provider.
	cred, err := h.repo.FindCredential(context.Background(), h.userID, provider.KindOpenAI, "")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(cred.APIKeyEncrypted), "SuperSecret") {
		t.Fatal("stored key is not encrypted")
	}
	plain, err := h.box.Open(cred.APIKeyEncrypted, []byte(h.userID.String()+"|openai|"))
	if err != nil || string(plain) != key {
		t.Fatalf("Open() = %q, %v", plain, err)
	}

	// GET never returns it either.
	if g := h.do(http.MethodGet, "/v1/ai/settings", nil); strings.Contains(g.raw, "SuperSecret") {
		t.Fatalf("GET leaks the key: %s", g.raw)
	}
}

func TestSettings_KeyKeptClearedAndRequired(t *testing.T) {
	h := newHarness(t)
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "anthropic", "model": "claude-test", "api_key": "sk-ant-abcdefghijkl", "max_output_tokens": 4096, "version": 0,
	}), http.StatusOK)

	// Omitted key: kept, model changed.
	r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "anthropic", "model": "claude-other", "max_output_tokens": 4096, "version": 1,
	})
	h.mustStatus(r, http.StatusOK)
	if active := r.body["active"].(map[string]any); active["has_key"] != true || active["model"] != "claude-other" {
		t.Fatalf("active = %v", active)
	}

	// Empty key on a provider that needs one: refused.
	r = h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "anthropic", "model": "claude-other", "api_key": "", "max_output_tokens": 4096, "version": 2,
	})
	if r.status != http.StatusUnprocessableEntity || r.fieldError("api_key") != "REQUIRED_FIELD" {
		t.Fatalf("empty key = %d %s", r.status, r.raw)
	}

	// New provider without any key: refused.
	r = h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "gemini", "model": "gemini-test", "max_output_tokens": 4096, "version": 2,
	})
	if r.fieldError("api_key") != "REQUIRED_FIELD" {
		t.Fatalf("gemini without key = %d %s", r.status, r.raw)
	}

	// Stale version: conflict.
	r = h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "anthropic", "model": "claude-test", "max_output_tokens": 4096, "version": 1,
	})
	if r.status != http.StatusConflict {
		t.Fatalf("stale version = %d, want 409", r.status)
	}
}

func TestSettings_Validation(t *testing.T) {
	h := newHarness(t)
	cases := []struct {
		name  string
		body  map[string]any
		field string
		code  string
	}{
		{"unknown provider", map[string]any{"provider": "acme", "model": "m", "api_key": "k", "max_output_tokens": 1000}, "provider", ai.FieldProviderInvalid},
		{"missing model", map[string]any{"provider": "openai", "api_key": "k", "max_output_tokens": 1000}, "model", "REQUIRED_FIELD"},
		{"tokens out of range", map[string]any{"provider": "openai", "model": "m", "api_key": "k", "max_output_tokens": 10}, "max_output_tokens", ai.FieldOutOfRange},
		{"negative price", map[string]any{"provider": "openai", "model": "m", "api_key": "k", "max_output_tokens": 1000, "output_price_per_mtok": -1}, "output_price_per_mtok", "NEGATIVE_NOT_ALLOWED"},
		{"compatible http", map[string]any{"provider": "openai_compatible", "base_url": "http://api.example.com/v1", "model": "m", "max_output_tokens": 1000}, "base_url", ai.FieldBaseURLInvalid},
		{"compatible private ip", map[string]any{"provider": "openai_compatible", "base_url": "https://10.0.0.1/v1", "model": "m", "max_output_tokens": 1000}, "base_url", ai.FieldBaseURLNotAllowed},
		{"compatible metadata", map[string]any{"provider": "openai_compatible", "base_url": "https://169.254.169.254", "model": "m", "max_output_tokens": 1000}, "base_url", ai.FieldBaseURLNotAllowed},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r := h.do(http.MethodPut, "/v1/ai/settings", c.body)
			if r.status != http.StatusUnprocessableEntity || r.fieldError(c.field) != c.code {
				t.Fatalf("= %d %s, want %s=%s", r.status, r.raw, c.field, c.code)
			}
		})
	}
}

func TestSettings_CompatibleProviderWithoutKey(t *testing.T) {
	h := newHarness(t)
	r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "openai_compatible", "base_url": "https://llm.example.com/v1/", "model": "llama", "max_output_tokens": 1000, "version": 0,
	})
	h.mustStatus(r, http.StatusOK)
	active := r.body["active"].(map[string]any)
	if active["base_url"] != "https://llm.example.com/v1" || active["has_key"] != false {
		t.Fatalf("active = %v", active)
	}
	if setup := r.body["setup"].(map[string]any); setup["has_provider"] != true {
		t.Fatalf("a keyless compatible provider counts as configured: %v", setup)
	}
}

func TestTestConnection_UsesStoredKeyAndRecordsResult(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-stored-key-0001")
	h.fake.Deltas = []string{"OK"}

	r := h.do(http.MethodPost, "/v1/ai/settings/test", nil)
	h.mustStatus(r, http.StatusOK)
	if r.body["ok"] != true || r.body["model"] != "gpt-test" {
		t.Fatalf("test = %s", r.raw)
	}
	last := h.factory.Configs[len(h.factory.Configs)-1]
	if last.APIKey != "sk-stored-key-0001" || last.Kind != provider.KindOpenAI {
		t.Fatalf("factory config = %+v", last)
	}
	if req := h.fake.LastRequest(); req.Model != "gpt-test" || req.MaxTokens > 16 {
		t.Fatalf("probe request = %+v", req)
	}
	settings := h.do(http.MethodGet, "/v1/ai/settings", nil)
	if active := settings.body["active"].(map[string]any); active["last_test_ok"] != true || active["last_tested_at"] == nil {
		t.Fatalf("test result not recorded: %v", active)
	}

	// A failing provider is reported in the body, not as an HTTP error.
	h.fake.Err = &provider.Error{Kind: provider.ErrInvalidKey, Status: 401, Message: "bad key"}
	r = h.do(http.MethodPost, "/v1/ai/settings/test", nil)
	h.mustStatus(r, http.StatusOK)
	if r.body["ok"] != false || r.body["error_code"] != "AI_PROVIDER_INVALID_KEY" {
		t.Fatalf("failed test = %s", r.raw)
	}
}

func TestTestConnection_UnsavedFormKeyIsNotRecorded(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-stored-key-0001")

	r := h.do(http.MethodPost, "/v1/ai/settings/test", map[string]any{"provider": "openai", "api_key": "sk-new-key-0002"})
	h.mustStatus(r, http.StatusOK)
	if last := h.factory.Configs[len(h.factory.Configs)-1]; last.APIKey != "sk-new-key-0002" {
		t.Fatalf("form key not used: %+v", last)
	}
	settings := h.do(http.MethodGet, "/v1/ai/settings", nil)
	if active := settings.body["active"].(map[string]any); active["last_tested_at"] != nil {
		t.Fatal("a test with an unsaved key must not mark the stored key as tested")
	}

	// Nothing configured and no provider given.
	h2 := newHarness(t)
	if r := h2.do(http.MethodPost, "/v1/ai/settings/test", nil); r.errorCode() != "AI_NOT_CONFIGURED" {
		t.Fatalf("unconfigured test = %d %s", r.status, r.raw)
	}
}

func TestListModels(t *testing.T) {
	h := newHarness(t)
	h.fake.Models = []provider.ModelInfo{{ID: "a"}, {ID: "b", DisplayName: "Bee"}}
	r := h.do(http.MethodPost, "/v1/ai/models", map[string]any{"provider": "gemini", "api_key": "AIza-x"})
	h.mustStatus(r, http.StatusOK)
	models := r.body["models"].([]any)
	if len(models) != 2 || models[0].(map[string]any)["display_name"] != "a" || models[1].(map[string]any)["display_name"] != "Bee" {
		t.Fatalf("models = %v", models)
	}

	h.fake.ModelsErr = &provider.Error{Kind: provider.ErrRateLimited, Status: 429}
	if r := h.do(http.MethodPost, "/v1/ai/models", map[string]any{"provider": "gemini", "api_key": "AIza-x"}); r.status != 429 || r.errorCode() != "AI_PROVIDER_RATE_LIMITED" {
		t.Fatalf("rate limited = %d %s", r.status, r.raw)
	}
}

func TestDeleteCredential_ClearsActive(t *testing.T) {
	h := newHarness(t)
	body := h.configure("sk-delete-me-0001")
	id := body["active"].(map[string]any)["id"].(string)

	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/credentials/"+id, nil), http.StatusNoContent)
	r := h.do(http.MethodGet, "/v1/ai/settings", nil)
	if r.body["active"] != nil || len(r.body["credentials"].([]any)) != 0 {
		t.Fatalf("after delete = %s", r.raw)
	}
	if r := h.do(http.MethodDelete, "/v1/ai/credentials/"+id, nil); r.status != http.StatusNotFound {
		t.Fatalf("second delete = %d", r.status)
	}
}

func TestConsent(t *testing.T) {
	h := newHarness(t)
	if r := h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": ai.ConsentVersion + 1}); r.fieldError("consent_version") != ai.FieldConsentVersionInvalid {
		t.Fatalf("wrong version = %s", r.raw)
	}
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": ai.ConsentVersion}), http.StatusNoContent)
	consent := h.do(http.MethodGet, "/v1/ai/settings", nil).body["consent"].(map[string]any)
	if consent["required"] != false || consent["accepted_version"] != float64(ai.ConsentVersion) || consent["accepted_at"] == nil {
		t.Fatalf("consent = %v", consent)
	}
	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/consent", nil), http.StatusNoContent)
	if consent := h.do(http.MethodGet, "/v1/ai/settings", nil).body["consent"].(map[string]any); consent["required"] != true {
		t.Fatalf("after revoke = %v", consent)
	}
}

func TestUserContext(t *testing.T) {
	h := newHarness(t)
	r := h.do(http.MethodGet, "/v1/ai/context", nil)
	h.mustStatus(r, http.StatusOK)
	if r.body["version"] != float64(0) {
		t.Fatalf("empty context = %s", r.raw)
	}

	r = h.do(http.MethodPut, "/v1/ai/context", map[string]any{
		"household_size": 3, "income_type": "EMPLOYEE", "about_me": "  Vivo a Milano  ", "goals": "",
		"response_style": "CONCISE", "version": 0,
	})
	h.mustStatus(r, http.StatusOK)
	if r.body["about_me"] != "Vivo a Milano" || r.body["goals"] != nil || r.body["version"] != float64(1) {
		t.Fatalf("saved = %s", r.raw)
	}
	if setup := h.do(http.MethodGet, "/v1/ai/settings", nil).body["setup"].(map[string]any); setup["has_context"] != true {
		t.Fatalf("setup.has_context = %v", setup)
	}

	if r := h.do(http.MethodPut, "/v1/ai/context", map[string]any{"version": 0}); r.status != http.StatusConflict {
		t.Fatalf("stale version = %d", r.status)
	}

	invalid := h.do(http.MethodPut, "/v1/ai/context", map[string]any{
		"household_size": 0, "income_type": "ASTRONAUT", "response_style": "LOUD",
		"ignore_notes": strings.Repeat("x", ai.MaxContextTextLength+1), "version": 1,
	})
	for field, code := range map[string]string{
		"household_size": ai.FieldOutOfRange, "income_type": ai.FieldInvalidValue,
		"response_style": ai.FieldInvalidValue, "ignore_notes": ai.FieldTextTooLong,
	} {
		if invalid.fieldError(field) != code {
			t.Errorf("%s = %q, want %s (%s)", field, invalid.fieldError(field), code, invalid.raw)
		}
	}
}

func TestAccountDeletionCascades(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-cascade-0001")
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/context", map[string]any{"goals": "Risparmiare", "version": 0}), http.StatusOK)

	if _, err := h.db.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, h.userID); err != nil {
		t.Fatalf("delete user: %v", err)
	}
	var n int
	err := h.db.QueryRow(context.Background(), `
		SELECT (SELECT count(*) FROM ai_provider_credentials WHERE user_id = $1)
		     + (SELECT count(*) FROM ai_settings WHERE user_id = $1)
		     + (SELECT count(*) FROM ai_user_context WHERE user_id = $1)`, h.userID).Scan(&n)
	if err != nil || n != 0 {
		t.Fatalf("rows left = %d, err = %v", n, err)
	}
}
