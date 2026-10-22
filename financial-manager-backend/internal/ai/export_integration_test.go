package ai_test

import (
	"context"
	"net/http"
	"testing"

	"financial-manager-backend/internal/ai"
)

// TestListAnalysesForExport: every analysis of the user, oldest first,
// with its whole conversation; nobody else's.
func TestListAnalysesForExport(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-export-0001")
	h.seedLedger()
	h.fake.Deltas = []string{"Primo report."}
	first := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	firstID := first.events[0].data["analysis_id"].(string)
	h.fake.Deltas = []string{"Risposta."}
	h.stream("/v1/ai/analyses/"+firstID+"/messages", map[string]any{"content": "Perché?"}, nil)
	h.fake.Deltas = []string{"Secondo report."}
	second := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	secondID := second.events[0].data["analysis_id"].(string)

	other := newHarness(t)
	other.configure("sk-export-0002")
	other.seedLedger()
	other.fake.Deltas = []string{"Di un altro."}
	other.stream("/v1/ai/analyses", other.runBody(previewBody(nil)), nil)

	got, err := h.repo.ListAnalysesForExport(context.Background(), h.userID)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].Analysis.ID.String() != firstID || got[1].Analysis.ID.String() != secondID {
		t.Fatalf("analyses = %+v", got)
	}
	kinds := []string{}
	for _, m := range got[0].Messages {
		kinds = append(kinds, m.Kind)
	}
	want := []string{ai.KindContext, ai.KindReport, ai.KindQuestion, ai.KindAnswer}
	if len(kinds) != len(want) {
		t.Fatalf("messages = %v", kinds)
	}
	for i := range want {
		if kinds[i] != want[i] {
			t.Fatalf("messages = %v, want %v", kinds, want)
		}
	}
	if got[0].Messages[1].Content != "Primo report." || got[0].Messages[3].Content != "Risposta." {
		t.Fatalf("contents = %q / %q", got[0].Messages[1].Content, got[0].Messages[3].Content)
	}

	// Deleting the history leaves nothing to export.
	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/analyses", nil), http.StatusNoContent)
	if got, _ := h.repo.ListAnalysesForExport(context.Background(), h.userID); len(got) != 0 {
		t.Fatalf("after deleting the history = %d", len(got))
	}
}
