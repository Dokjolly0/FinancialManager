package ai_test

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/transactions"
)

func toolCall(id, name, args string) provider.ToolCall {
	return provider.ToolCall{ID: id, Name: name, Args: json.RawMessage(args)}
}

// seedOld adds transactions older than the period the tests look at.
func (h *harness) seedOld() {
	old := time.Date(2024, 6, 1, 9, 0, 0, 0, time.UTC)
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 48000, "Assicurazione macchina", old)
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 6000, "Benzina", old.AddDate(0, 1, 0))
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 5500, "Benzina", old.AddDate(0, 2, 0))
}

func TestChatTools_SearchThenAnswer(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0001")
	h.seedLedger()
	h.seedOld()
	h.fake.Turns = []provider.ScriptedTurn{
		{Deltas: []string{"Cerco. "}, ToolCalls: []provider.ToolCall{
			toolCall("c1", "search_transactions", `{"query":"assicurazione della macchina"}`),
		}, Result: provider.StreamResult{InputTokens: 100, OutputTokens: 10}},
		{Deltas: []string{"Il 1 giugno 2024."}, Result: provider.StreamResult{InputTokens: 150, OutputTokens: 8}},
	}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody("Quando ho pagato l'assicurazione?", nil)), nil)
	if res.status != http.StatusOK || res.text() != "Cerco. \n\nIl 1 giugno 2024." {
		t.Fatalf("stream = %d %v %q", res.status, res.names(), res.text())
	}
	tool := res.last("tool")
	if tool["name"] != "search_transactions" || tool["query"] != "assicurazione della macchina" {
		t.Fatalf("tool event = %v (events %v)", tool, res.names())
	}
	if names := strings.Join(res.names(), ","); !strings.HasPrefix(names, "meta,delta,tool,delta") || !strings.HasSuffix(names, "usage,done") {
		t.Fatalf("event order = %s", names)
	}

	if len(h.fake.Requests) != 2 || len(h.fake.Requests[0].Tools) != 2 || h.fake.Requests[0].NoMoreToolCalls {
		t.Fatalf("first request = %+v", h.fake.Requests[0])
	}
	second := h.fake.LastRequest().Messages
	call, results := second[len(second)-2], second[len(second)-1]
	if call.Role != provider.RoleAssistant || call.Content != "Cerco." || len(call.ToolCalls) != 1 ||
		results.Role != provider.RoleUser || len(results.ToolResults) != 1 || results.ToolResults[0].CallID != "c1" ||
		!strings.Contains(results.ToolResults[0].Content, "| Assicurazione macchina |") ||
		!strings.Contains(results.ToolResults[0].Content, "<financial_data>") {
		t.Fatalf("tool round = %+v / %+v", call, results)
	}

	id := res.events[0].data["analysis_id"].(string)
	detail := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil)
	if detail.body["input_tokens"] != float64(250) || detail.body["output_tokens"] != float64(18) {
		t.Fatalf("tokens of both rounds = %v / %v", detail.body["input_tokens"], detail.body["output_tokens"])
	}
	trace := detail.body["messages"].([]any)[1].(map[string]any)["tool_trace"].([]any)
	entry := trace[0].(map[string]any)
	if len(trace) != 1 || entry["name"] != "search_transactions" || entry["rows"] != float64(1) ||
		!strings.Contains(entry["result"].(string), "Assicurazione macchina") {
		t.Fatalf("trace = %v", trace)
	}
	exported, err := h.repo.ListAnalysesForExport(context.Background(), h.userID)
	if err != nil || len(exported[0].Messages[1].ToolTrace) != 1 {
		t.Fatalf("exported trace = %+v (%v)", exported, err)
	}

	// A follow-up replays only the final texts and offers the tools again.
	h.fake.Turns = nil
	h.fake.Deltas = []string{"Ok."}
	h.stream("/v1/ai/analyses/"+id+"/messages", map[string]any{"content": "E il bollo?"}, nil)
	sent := h.fake.LastRequest()
	if len(sent.Tools) != 2 || len(sent.Messages) != 3 || sent.Messages[1].Content != "Cerco. \n\nIl 1 giugno 2024." ||
		len(sent.Messages[1].ToolCalls) != 0 {
		t.Fatalf("follow-up = %+v", sent)
	}
}

func TestChatTools_SumByMonthAndScope(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0002")
	h.seedLedger()
	h.seedOld()
	other := h.secondWallet("Carta", "Spese online")
	h.seed(other, transactions.DirectionDebit, transactions.KindStandard, 9900, "Benzina", time.Date(2024, 7, 2, 9, 0, 0, 0, time.UTC))
	stranger := newHarness(t)
	stranger.seed(stranger.walletID, transactions.DirectionDebit, transactions.KindStandard, 7700, "Benzina", time.Date(2024, 7, 3, 9, 0, 0, 0, time.UTC))

	h.fake.Turns = []provider.ScriptedTurn{
		{ToolCalls: []provider.ToolCall{
			toolCall("s1", "sum_transactions", `{"query":"benzina","group_by":"month","direction":"DEBIT","to":"2024-12-31"}`),
			toolCall("s2", "search_transactions", `{"min_amount":100,"limit":5}`),
		}},
		{Deltas: []string{"Circa 57.50 al mese."}},
	}
	body := chatBody("Quanto spendo di benzina al mese?", nil)
	body["wallet_ids"] = []string{h.walletID.String()}
	h.stream("/v1/ai/analyses", h.runBody(body), nil)
	results := h.fake.LastRequest().Messages[2].ToolResults
	sums, big := results[0].Content, results[1].Content
	// Only the chat's wallet, only this user: July holds 55.00, not 99.00 or 77.00.
	for _, want := range []string{"gruppo | uscite | entrate | movimenti", "2024-07 | 60.00 | 0.00 | 1", "2024-08 | 55.00 | 0.00 | 1"} {
		if !strings.Contains(sums, want) {
			t.Errorf("sums lack %q:\n%s", want, sums)
		}
	}
	if strings.Contains(sums, "99.00") || strings.Contains(sums, "77.00") || strings.Contains(sums, "2025") {
		t.Errorf("sums outside the chat's scope or the asked period:\n%s", sums)
	}
	// Amounts of at least 100.00, newest first, at most 5.
	if !strings.Contains(big, "Trovati 9 movimenti, mostrati 5") || strings.Contains(big, "| Netflix |") {
		t.Errorf("big expenses:\n%s", big)
	}
}

// Bad arguments go back to the model; the answer still completes.
func TestChatTools_BadArguments(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0003")
	h.seedLedger()
	h.fake.Turns = []provider.ScriptedTurn{
		{ToolCalls: []provider.ToolCall{
			toolCall("b1", "search_transactions", `{"from":"ieri"}`),
			toolCall("b2", "search_transactions", `{"limit":500}`),
			toolCall("b3", "sum_transactions", `{"group_by":"week"}`),
			toolCall("b4", "delete_everything", `{}`),
			toolCall("b5", "search_transactions", `not json`),
		}},
		{Deltas: []string{"Non riesco a cercare."}},
	}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody("Quando?", nil)), nil)
	if res.last("done")["status"] != "COMPLETED" {
		t.Fatalf("stream = %v %q", res.names(), res.text())
	}
	for i, want := range []string{"from must be a date", "limit must be between 1 and 50", "group_by must be", `unknown tool \"delete_everything\"`, "not a JSON object"} {
		got := h.fake.LastRequest().Messages[2].ToolResults[i].Content
		if !strings.HasPrefix(got, "Ricerca non eseguita: ") || !strings.Contains(got, strings.ReplaceAll(want, `\"`, `"`)) {
			t.Errorf("result %d = %q, want %q", i, got, want)
		}
	}
}

// After maxToolRounds rounds of calls the model must answer.
func TestChatTools_RoundLimit(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0004")
	h.seedLedger()
	h.fake.Turns = []provider.ScriptedTurn{{
		Deltas:    []string{"."},
		ToolCalls: []provider.ToolCall{toolCall("r", "search_transactions", `{"query":"netflix"}`)},
	}}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody("Quanto costa Netflix?", nil)), nil)
	if res.last("done")["status"] != "COMPLETED" || len(h.fake.Requests) != 4 {
		t.Fatalf("rounds = %d, events %v", len(h.fake.Requests), res.names())
	}
	for i, r := range h.fake.Requests {
		if r.NoMoreToolCalls != (i == 3) {
			t.Errorf("round %d NoMoreToolCalls = %v", i+1, r.NoMoreToolCalls)
		}
	}
	id := res.events[0].data["analysis_id"].(string)
	trace := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil).body["messages"].([]any)[1].(map[string]any)["tool_trace"].([]any)
	if len(trace) != 3 {
		t.Fatalf("trace = %d calls, want 3", len(trace))
	}
}

// A server without function calling answers from the data already sent.
func TestChatTools_UnsupportedFallsBack(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0005")
	h.seedLedger()
	h.fake.RejectTools = true
	h.fake.Deltas = []string{"Ogni mese, 12.99."}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody("Quanto costa Netflix?", nil)), nil)
	if res.text() != "Ogni mese, 12.99." || res.last("done")["status"] != "COMPLETED" {
		t.Fatalf("stream = %v %q", res.names(), res.text())
	}
	if len(h.fake.Requests) != 2 || len(h.fake.Requests[0].Tools) == 0 || h.fake.Requests[1].Tools != nil {
		t.Fatalf("requests = %+v", h.fake.Requests)
	}
	id := res.events[0].data["analysis_id"].(string)
	if trace := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil).body["messages"].([]any)[1].(map[string]any)["tool_trace"]; trace != nil {
		t.Fatalf("trace without tools = %v", trace)
	}
}

// Reports never offer tools, whatever the model returns.
func TestReports_NoTools(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-tools-0006")
	h.seedLedger()
	h.fake.Turns = []provider.ScriptedTurn{{
		Deltas: []string{"Report."}, ToolCalls: []provider.ToolCall{toolCall("x", "search_transactions", `{}`)},
	}}
	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	if len(h.fake.Requests) != 1 || h.fake.Requests[0].Tools != nil || res.last("tool") != nil {
		t.Fatalf("report requests = %+v, events %v", h.fake.Requests, res.names())
	}
}
