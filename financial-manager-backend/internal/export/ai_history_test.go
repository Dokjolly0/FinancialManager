package export

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/users"
)

func TestAIHistoryInTheJSONExport(t *testing.T) {
	now := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	report := "## Sintesi\nHai speso meno."
	tokens := 120
	duration := 42000
	history := []ai.AnalysisWithMessages{
		{
			Analysis: ai.Analysis{
				ID: uuid.New(), Title: "Check-up", Preset: "MONTHLY_CHECKUP", PeriodTo: now, Timezone: "Europe/Rome",
				Provider: ai.ProviderOnDevice, Model: "Gemma 4 E2B · int4 · LiteRT-LM", Status: ai.StatusCompleted,
				Runtime:   &ai.LocalRuntime{Engine: "litert_lm", ModelID: "gemma4-e2b-litert", Backend: "gpu"},
				CreatedAt: now, UpdatedAt: now,
			},
			Messages: []ai.Message{
				{Kind: ai.KindContext, Content: "<financial_data>…</financial_data>", Status: ai.StatusCompleted, CreatedAt: now, UpdatedAt: now},
				{Kind: ai.KindReport, Content: report, Status: ai.StatusCompleted, OutputTokens: &tokens, DurationMs: &duration, CreatedAt: now, UpdatedAt: now},
			},
		},
		{
			// A cloud stream that died long ago: exported as failed, like the app shows it.
			Analysis: ai.Analysis{
				ID: uuid.New(), Title: "Abbonamenti", Preset: "RECURRING", PeriodTo: now, Provider: "openai", Model: "gpt-test",
				Status: ai.StatusStreaming, CreatedAt: now.Add(-time.Hour), UpdatedAt: now.Add(-time.Hour),
			},
			Messages: []ai.Message{
				{Kind: ai.KindReport, Status: ai.StatusStreaming, CreatedAt: now.Add(-time.Hour), UpdatedAt: now.Add(-time.Hour)},
			},
		},
	}
	s := NewService(Deps{})
	body, err := buildJSON(users.User{CreatedAt: now}, nil, nil, nil, nil, nil, s.toAIAnalysesJSON(history, now))
	if err != nil {
		t.Fatal(err)
	}
	var decoded struct {
		Analyses []struct {
			Title    string          `json:"titolo"`
			Provider string          `json:"fornitore"`
			Status   string          `json:"stato"`
			Runtime  json.RawMessage `json:"esecuzione"`
			Messages []struct {
				Kind       string `json:"tipo"`
				Content    string `json:"contenuto"`
				Status     string `json:"stato"`
				DurationMs int    `json:"durata_ms"`
			} `json:"messaggi"`
		} `json:"analisi_ai"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatal(err)
	}
	if len(decoded.Analyses) != 2 {
		t.Fatalf("analisi_ai = %s", body)
	}
	local := decoded.Analyses[0]
	if local.Provider != "on_device" || local.Status != ai.StatusCompleted || !strings.Contains(string(local.Runtime), "gemma4-e2b-litert") {
		t.Fatalf("on-device analysis = %+v", local)
	}
	if len(local.Messages) != 2 || local.Messages[0].Kind != ai.KindContext || local.Messages[1].Content != report ||
		local.Messages[1].DurationMs != duration {
		t.Fatalf("messages = %+v", local.Messages)
	}
	if stale := decoded.Analyses[1]; stale.Status != ai.StatusFailed || stale.Messages[0].Status != ai.StatusFailed {
		t.Fatalf("stale cloud analysis = %+v", stale)
	}

	// No history: no key at all.
	body, _ = buildJSON(users.User{CreatedAt: now}, nil, nil, nil, nil, nil, s.toAIAnalysesJSON(nil, now))
	if strings.Contains(string(body), "analisi_ai") {
		t.Fatalf("empty history exported: %s", body)
	}
}
