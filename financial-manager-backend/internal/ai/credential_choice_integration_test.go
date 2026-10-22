package ai_test

import (
	"net/http"
	"testing"

	"github.com/google/uuid"
)

// TestRun_ChosenCredential: an analysis may run with any stored provider
// account, not only the active one, and its follow-ups stay on it.
func TestRun_ChosenCredential(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-openai-0001")
	h.seedLedger()
	settings := h.do(http.MethodGet, "/v1/ai/settings", nil).body
	openaiID := settings["active"].(map[string]any)["id"].(string)

	// A second account becomes the active one.
	r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{
		"provider": "gemini", "model": "gemini-test", "api_key": "AIza-gemini-0001", "max_output_tokens": 2048,
		"version": settings["version"],
	})
	h.mustStatus(r, http.StatusOK)
	if r.body["active"].(map[string]any)["provider"] != "gemini" {
		t.Fatalf("active = %v", r.body["active"])
	}

	body := previewBody(map[string]any{"credential_id": openaiID})
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	if p.body["provider"] != "openai" || p.body["model"] != "gpt-test" {
		t.Fatalf("preview with a chosen credential = %v / %v", p.body["provider"], p.body["model"])
	}

	h.fake.Deltas = []string{"Report."}
	res := h.stream("/v1/ai/analyses", h.runBody(body), nil)
	if res.status != http.StatusOK {
		t.Fatalf("run = %d %s", res.status, res.raw)
	}
	if sent := h.fake.LastRequest(); sent.Model != "gpt-test" {
		t.Fatalf("run used model %q", sent.Model)
	}
	analysisID := res.events[0].data["analysis_id"].(string)
	if d := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil); d.body["provider"] != "openai" || d.body["model"] != "gpt-test" {
		t.Fatalf("stored analysis = %v / %v", d.body["provider"], d.body["model"])
	}

	// Follow-ups continue with the analysis's account, not the active one.
	h.fake.Deltas = []string{"Risposta."}
	h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "Perché?"}, nil)
	if sent := h.fake.LastRequest(); sent.Model != "gpt-test" {
		t.Fatalf("follow-up used model %q", sent.Model)
	}

	// Without a choice the active account runs.
	if p := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(nil)); p.body["model"] != "gemini-test" {
		t.Fatalf("default preview model = %v", p.body["model"])
	}

	// Once that account is removed, follow-ups fall back to the active one.
	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/credentials/"+openaiID, nil), http.StatusNoContent)
	h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "E adesso?"}, nil)
	if sent := h.fake.LastRequest(); sent.Model != "gemini-test" {
		t.Fatalf("follow-up after removal used model %q", sent.Model)
	}

	// Ids that aren't the user's credentials are refused.
	for id, want := range map[string]string{"not-a-uuid": "INVALID_UUID", uuid.NewString(): "INVALID_VALUE", openaiID: "INVALID_VALUE"} {
		r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{"credential_id": id}))
		if r.status != http.StatusUnprocessableEntity || r.fieldError("credential_id") != want {
			t.Fatalf("credential_id %s = %d %s", id, r.status, r.raw)
		}
	}
	other := newHarness(t)
	other.configure("sk-other-0002")
	activeID := h.do(http.MethodGet, "/v1/ai/settings", nil).body["active"].(map[string]any)["id"].(string)
	if r := other.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{"credential_id": activeID})); r.fieldError("credential_id") != "INVALID_VALUE" {
		t.Fatalf("someone else's credential = %d %s", r.status, r.raw)
	}
}
