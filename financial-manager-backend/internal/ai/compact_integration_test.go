package ai_test

import (
	"net/http"
	"strings"
	"testing"
)

func compactBody(options map[string]any) map[string]any {
	opts := map[string]any{
		"sections":             []string{"monthly", "categories", "titles", "transfers", "recurring", "personal_context"},
		"include_transactions": true,
	}
	for k, v := range options {
		opts[k] = v
	}
	return map[string]any{"preset": "ANOMALIES", "period": map[string]any{"preset": "last_12_months"}, "options": opts}
}

func TestPreview_CompactProfileAndBudget(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-compact-0001")
	h.seedLedger()

	std := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(nil))
	h.mustStatus(std, http.StatusOK)
	cmp := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(map[string]any{"profile": "compact"}))
	h.mustStatus(cmp, http.StatusOK)
	if cmp.body["estimated_input_tokens"].(float64) >= std.body["estimated_input_tokens"].(float64) {
		t.Fatalf("compact (%v) must be smaller than standard (%v)", cmp.body["estimated_input_tokens"], std.body["estimated_input_tokens"])
	}
	if d := cmp.body["disclosure"].(map[string]any); d["profile"] != "compact" || len(d["compaction_steps"].([]any)) != 0 {
		t.Fatalf("disclosure = %v", d)
	}

	// The seeded ledger is small: a budget of 1000 tokens forces steps.
	tight := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(map[string]any{"profile": "compact", "budget_tokens": 1000}))
	h.mustStatus(tight, http.StatusOK)
	steps := tight.body["disclosure"].(map[string]any)["compaction_steps"].([]any)
	if tight.body["estimated_input_tokens"].(float64) > 1000 {
		t.Fatalf("estimate %v over budget (steps %v)", tight.body["estimated_input_tokens"], steps)
	}
	if len(steps) == 0 || steps[0] != "transactions_30" {
		t.Fatalf("steps = %v", steps)
	}
	if strings.Contains(tight.body["data_block"].(string), "## Movimenti") && len(steps) > 1 {
		t.Fatal("transactions should be gone after transactions_0")
	}

	// Same request, same fingerprint: the run rebuilds what was previewed.
	again := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(map[string]any{"profile": "compact", "budget_tokens": 1000}))
	if again.body["data_fingerprint"] != tight.body["data_fingerprint"] {
		t.Fatal("budget fitting is not deterministic")
	}
	h.fake.Deltas = []string{"ok"}
	run := h.stream("/v1/ai/analyses", h.runBody(compactBody(map[string]any{"profile": "compact", "budget_tokens": 1000})), nil)
	if run.status != http.StatusOK {
		t.Fatalf("compact run = %d %s", run.status, run.raw)
	}
	if sys := h.fake.LastRequest().System; !strings.Contains(sys, "Usa SOLO i numeri presenti") {
		t.Fatalf("the compact run must send the compact rules:\n%s", sys)
	}
}

func TestPreview_CompactValidation(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-compact-0002")
	h.seedLedger()
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(map[string]any{"profile": "tiny"})); r.fieldError("options.profile") == "" {
		t.Fatalf("bad profile = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", compactBody(map[string]any{"budget_tokens": 10})); r.fieldError("options.budget_tokens") == "" {
		t.Fatalf("bad budget = %d %s", r.status, r.raw)
	}
	// Long instructions can't be compacted away: the budget is unreachable.
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", map[string]any{
		"preset": "CUSTOM", "instructions": strings.Repeat("Analizza tutto con cura. ", 160),
		"period": map[string]any{"preset": "last_12_months"}, "options": map[string]any{"budget_tokens": 1000},
	})
	if r.status != http.StatusUnprocessableEntity || r.errorCode() != "AI_PROMPT_TOO_LARGE" {
		t.Fatalf("unreachable budget = %d %s", r.status, r.raw)
	}
}
