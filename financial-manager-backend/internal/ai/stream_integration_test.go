package ai_test

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/provider"
)

type sseEvent struct {
	name string
	data map[string]any
}

type streamResult struct {
	status int
	events []sseEvent
	raw    string // body of a non-SSE (JSON error) response
}

func (r streamResult) names() []string {
	out := make([]string, len(r.events))
	for i, e := range r.events {
		out[i] = e.name
	}
	return out
}

func (r streamResult) text() string {
	var b strings.Builder
	for _, e := range r.events {
		if e.name == "delta" {
			b.WriteString(e.data["text"].(string))
		}
	}
	return b.String()
}

func (r streamResult) last(name string) map[string]any {
	for i := len(r.events) - 1; i >= 0; i-- {
		if r.events[i].name == name {
			return r.events[i].data
		}
	}
	return nil
}

func (r streamResult) errorCode() string {
	var env struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	_ = json.Unmarshal([]byte(r.raw), &env)
	return env.Error.Code
}

// stream POSTs body and reads the whole event stream. onEvent may return
// false to hang up early (the client going away).
func (h *harness) stream(path string, body any, onEvent func(sseEvent) bool) streamResult {
	h.t.Helper()
	payload, _ := json.Marshal(body)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, h.server.URL+path, bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		h.t.Fatalf("POST %s: %v", path, err)
	}
	defer resp.Body.Close()
	out := streamResult{status: resp.StatusCode}
	if !strings.HasPrefix(resp.Header.Get("Content-Type"), "text/event-stream") {
		var b strings.Builder
		_, _ = bufio.NewReader(resp.Body).WriteTo(&b)
		out.raw = b.String()
		return out
	}
	scanner := bufio.NewScanner(resp.Body)
	var name string
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case strings.HasPrefix(line, "event: "):
			name = strings.TrimPrefix(line, "event: ")
		case strings.HasPrefix(line, "data: "):
			ev := sseEvent{name: name}
			_ = json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &ev.data)
			out.events = append(out.events, ev)
			if onEvent != nil && !onEvent(ev) {
				cancel()
				return out
			}
		}
	}
	return out
}

// runBody previews body and returns it ready to run.
func (h *harness) runBody(body map[string]any) map[string]any {
	h.t.Helper()
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	run := map[string]any{}
	for k, v := range body {
		run[k] = v
	}
	run["data_fingerprint"] = p.body["data_fingerprint"]
	run["client_request_id"] = uuid.NewString()
	return run
}

func (h *harness) waitForStatus(analysisID, want string) map[string]any {
	h.t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for {
		r := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil)
		if r.body["status"] == want || time.Now().After(deadline) {
			if r.body["status"] != want {
				h.t.Fatalf("analysis status = %v, want %s", r.body["status"], want)
			}
			return r.body
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func TestRun_StreamsAndStoresTheReport(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-run-0001")
	h.seedLedger()
	h.fake.Deltas = []string{"## Sintesi\n", "Hai speso ", "meno del ", "previsto."}
	h.fake.Result = provider.StreamResult{InputTokens: 1200, OutputTokens: 80}

	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	if res.status != http.StatusOK {
		t.Fatalf("status = %d %s", res.status, res.raw)
	}
	names := res.names()
	if names[0] != "meta" || names[len(names)-2] != "usage" || names[len(names)-1] != "done" {
		t.Fatalf("events = %v", names)
	}
	if res.text() != "## Sintesi\nHai speso meno del previsto." {
		t.Fatalf("streamed text = %q", res.text())
	}
	if done := res.last("done"); done["status"] != ai.StatusCompleted {
		t.Fatalf("done = %v", done)
	}
	analysisID := res.events[0].data["analysis_id"].(string)

	// What was sent: the stored system prompt and the previewed message.
	sent := h.fake.LastRequest()
	if !strings.Contains(sent.System, "<financial_data>") || len(sent.Messages) != 1 ||
		!strings.Contains(sent.Messages[0].Content, "Fammi un check-up") || !strings.Contains(sent.Messages[0].Content, "Netflix") ||
		sent.Model != "gpt-test" || sent.MaxTokens != 2048 {
		t.Fatalf("request sent = %+v", sent)
	}

	detail := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil)
	h.mustStatus(detail, http.StatusOK)
	if detail.body["status"] != ai.StatusCompleted || detail.body["input_tokens"] != float64(1200) ||
		detail.body["output_tokens"] != float64(80) || detail.body["can_ask_follow_ups"] != true {
		t.Fatalf("detail = %s", detail.raw)
	}
	msgs := detail.body["messages"].([]any)
	if len(msgs) != 2 {
		t.Fatalf("messages = %v", msgs)
	}
	context, report := msgs[0].(map[string]any), msgs[1].(map[string]any)
	if context["kind"] != "CONTEXT" || !strings.Contains(context["content"].(string), "<financial_data>") {
		t.Fatalf("context message = %v", context)
	}
	if report["kind"] != "REPORT" || report["content"] != res.text() || report["status"] != ai.StatusCompleted {
		t.Fatalf("report message = %v", report)
	}
	if !strings.HasPrefix(detail.body["title"].(string), "Check-up del periodo · 2025-10-20 → 2026-10-20") {
		t.Fatalf("title = %v", detail.body["title"])
	}

	if setup := h.do(http.MethodGet, "/v1/ai/settings", nil).body["setup"].(map[string]any); setup["analyses_count"] != float64(1) {
		t.Fatalf("setup = %v", setup)
	}
}

func TestRun_RefusedBeforeStreaming(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-run-0002")
	h.seedLedger()
	body := h.runBody(previewBody(nil))

	stale := map[string]any{}
	for k, v := range body {
		stale[k] = v
	}
	stale["data_fingerprint"] = strings.Repeat("0", 64)
	if res := h.stream("/v1/ai/analyses", stale, nil); res.status != http.StatusConflict || res.errorCode() != "AI_DATA_CHANGED" {
		t.Fatalf("stale fingerprint = %d %s", res.status, res.raw)
	}

	noID := map[string]any{}
	for k, v := range body {
		noID[k] = v
	}
	delete(noID, "client_request_id")
	if res := h.stream("/v1/ai/analyses", noID, nil); res.status != http.StatusUnprocessableEntity {
		t.Fatalf("missing client_request_id = %d %s", res.status, res.raw)
	}

	h.fake.Deltas = []string{"ok"}
	if res := h.stream("/v1/ai/analyses", body, nil); res.status != http.StatusOK {
		t.Fatalf("first run = %d %s", res.status, res.raw)
	}
	if res := h.stream("/v1/ai/analyses", body, nil); res.status != http.StatusConflict || res.errorCode() != "AI_ANALYSIS_EXISTS" {
		t.Fatalf("same client_request_id = %d %s", res.status, res.raw)
	}
}

func TestRun_ProviderErrorMidStream(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-run-0003")
	h.seedLedger()
	h.fake.Deltas = []string{"Inizio del report"}
	h.fake.Err = &provider.Error{Kind: provider.ErrUnavailable, Status: 529, Message: "Overloaded"}

	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	names := res.names()
	if names[len(names)-2] != "error" || names[len(names)-1] != "done" {
		t.Fatalf("events = %v", names)
	}
	if e := res.last("error"); e["code"] != "AI_PROVIDER_UNAVAILABLE" || e["message"] != "Overloaded" {
		t.Fatalf("error event = %v", e)
	}
	detail := h.waitForStatus(res.events[0].data["analysis_id"].(string), ai.StatusFailed)
	report := detail["messages"].([]any)[1].(map[string]any)
	if report["content"] != "Inizio del report" || report["error_code"] != "AI_PROVIDER_UNAVAILABLE" {
		t.Fatalf("partial report = %v", report)
	}
	if detail["can_ask_follow_ups"] != false {
		t.Fatal("no follow-ups on a failed report")
	}
	r := h.do(http.MethodPost, "/v1/ai/analyses/"+detail["id"].(string)+"/messages", map[string]any{"content": "Perché?"})
	if r.errorCode() != "AI_ANALYSIS_NOT_READY" {
		t.Fatalf("follow-up on failed report = %d %s", r.status, r.raw)
	}
}

func TestRun_ClientDisconnectCancels(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-run-0004")
	h.seedLedger()
	h.fake.Deltas = []string{"uno ", "due ", "tre ", "quattro ", "cinque ", "sei "}
	h.fake.DelayPerDelta = 150 * time.Millisecond

	var analysisID string
	h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), func(e sseEvent) bool {
		if e.name == "meta" {
			analysisID = e.data["analysis_id"].(string)
		}
		return e.name != "delta"
	})
	detail := h.waitForStatus(analysisID, ai.StatusCancelled)
	report := detail["messages"].([]any)[1].(map[string]any)
	if content := report["content"].(string); !strings.HasPrefix(content, "uno ") || strings.Contains(content, "sei") {
		t.Fatalf("partial content = %q", content)
	}

	// The lock was released: a new run can start.
	h.fake.DelayPerDelta = 0
	if res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil); res.status != http.StatusOK {
		t.Fatalf("run after cancel = %d %s", res.status, res.raw)
	}
}

func TestRun_OneStreamPerUser(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-run-0005")
	h.seedLedger()
	h.fake.Deltas = []string{"a", "b", "c", "d"}
	h.fake.DelayPerDelta = 200 * time.Millisecond

	started := make(chan struct{})
	finished := make(chan streamResult)
	go func() {
		finished <- h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), func(e sseEvent) bool {
			if e.name == "meta" {
				close(started)
			}
			return true
		})
	}()
	<-started
	second := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	if second.status != http.StatusConflict || second.errorCode() != "AI_STREAM_IN_PROGRESS" {
		t.Fatalf("second stream = %d %s", second.status, second.raw)
	}
	if first := <-finished; first.text() != "abcd" {
		t.Fatalf("first stream text = %q", first.text())
	}
}

func TestRun_OutlivesTheRequestTimeout(t *testing.T) {
	h := newHarness(t, harnessOptions{requestTimeout: 200 * time.Millisecond})
	h.configure("sk-run-0006")
	h.seedLedger()
	h.fake.Deltas = []string{"lento ", "ma ", "completo"}
	h.fake.DelayPerDelta = 150 * time.Millisecond

	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	if res.status != http.StatusOK || res.text() != "lento ma completo" || res.last("done")["status"] != ai.StatusCompleted {
		t.Fatalf("stream = %d %v %q", res.status, res.names(), res.text())
	}
}

func TestFollowUps(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-follow-0001")
	h.seedLedger()
	h.fake.Deltas = []string{"Report iniziale."}
	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	analysisID := res.events[0].data["analysis_id"].(string)
	system := h.fake.LastRequest().System

	h.fake.Deltas = []string{"Perché l'affitto ", "pesa molto."}
	h.fake.Result = provider.StreamResult{InputTokens: 50, OutputTokens: 10}
	first := h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "  Perché spendo tanto?  "}, nil)
	if first.status != http.StatusOK || first.text() != "Perché l'affitto pesa molto." || first.events[0].data["kind"] != "ANSWER" {
		t.Fatalf("first follow-up = %d %v %q", first.status, first.names(), first.text())
	}
	sent := h.fake.LastRequest()
	if sent.System != system || len(sent.Messages) != 3 || sent.Messages[1].Content != "Report iniziale." ||
		sent.Messages[2].Content != "Perché spendo tanto?" || sent.Messages[2].Role != provider.RoleUser {
		t.Fatalf("follow-up request = %+v", sent)
	}

	// A failed answer is left out of the next request with its question.
	h.fake.Err = &provider.Error{Kind: provider.ErrRateLimited, Status: 429}
	h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "Domanda persa"}, nil)
	h.fake.Err = nil
	h.fake.Deltas = []string{"Sì."}
	h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "Posso risparmiare?"}, nil)
	sent = h.fake.LastRequest()
	if len(sent.Messages) != 5 || sent.Messages[3].Content != "Perché l'affitto pesa molto." || sent.Messages[4].Content != "Posso risparmiare?" {
		t.Fatalf("history after a failed answer = %+v", sent.Messages)
	}

	detail := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil)
	if len(detail.body["messages"].([]any)) != 8 || detail.body["follow_ups_left"] != float64(ai.MaxFollowUps-3) {
		t.Fatalf("detail = %s", detail.raw)
	}
	if detail.body["input_tokens"].(float64) < 50 {
		t.Fatalf("follow-up tokens not added: %v", detail.body["input_tokens"])
	}

	if r := h.do(http.MethodPost, "/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "   "}); r.fieldError("content") != "REQUIRED_FIELD" {
		t.Fatalf("blank question = %s", r.raw)
	}
	other := newHarness(t)
	other.configure("sk-other-0001")
	if r := other.do(http.MethodPost, "/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "Ciao"}); r.status != http.StatusNotFound {
		t.Fatalf("someone else's analysis = %d", r.status)
	}
}

func TestFollowUps_Limit(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-follow-0002")
	h.seedLedger()
	h.fake.Deltas = []string{"Report."}
	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	analysisID := uuid.MustParse(res.events[0].data["analysis_id"].(string))

	for i := 0; i < ai.MaxFollowUps; i++ {
		_, answer, err := h.repo.AppendQuestion(context.Background(), analysisID, "Domanda", "gpt-test")
		if err != nil {
			t.Fatal(err)
		}
		if err := h.repo.FinishMessage(context.Background(), answer, ai.FinishInput{Content: "Risposta", Status: ai.StatusCompleted}); err != nil {
			t.Fatal(err)
		}
	}
	r := h.do(http.MethodPost, "/v1/ai/analyses/"+analysisID.String()+"/messages", map[string]any{"content": "Ancora una"})
	if r.errorCode() != "AI_FOLLOWUP_LIMIT" {
		t.Fatalf("over the limit = %d %s", r.status, r.raw)
	}
}

func TestHistory(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-history-0001")
	h.seedLedger()
	h.fake.Deltas = []string{"ok"}
	var ids []string
	for i := 0; i < 3; i++ {
		res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
		ids = append(ids, res.events[0].data["analysis_id"].(string))
	}

	page1 := h.do(http.MethodGet, "/v1/ai/analyses?limit=2", nil)
	h.mustStatus(page1, http.StatusOK)
	items := page1.body["items"].([]any)
	if len(items) != 2 || items[0].(map[string]any)["id"] != ids[2] || page1.body["next_cursor"] == nil {
		t.Fatalf("page 1 = %s", page1.raw)
	}
	page2 := h.do(http.MethodGet, "/v1/ai/analyses?limit=2&cursor="+page1.body["next_cursor"].(string), nil)
	items2 := page2.body["items"].([]any)
	if len(items2) != 1 || items2[0].(map[string]any)["id"] != ids[0] || page2.body["next_cursor"] != nil {
		t.Fatalf("page 2 = %s", page2.raw)
	}
	if r := h.do(http.MethodGet, "/v1/ai/analyses?cursor=bm90LWEtY3Vyc29y", nil); r.status != http.StatusUnprocessableEntity {
		t.Fatalf("bad cursor = %d", r.status)
	}

	renamed := h.do(http.MethodPatch, "/v1/ai/analyses/"+ids[0], map[string]any{"title": "  Spese estive  "})
	if renamed.status != http.StatusOK || renamed.body["title"] != "Spese estive" {
		t.Fatalf("rename = %s", renamed.raw)
	}
	if r := h.do(http.MethodPatch, "/v1/ai/analyses/"+ids[0], map[string]any{"title": ""}); r.fieldError("title") != "REQUIRED_FIELD" {
		t.Fatalf("empty title = %s", r.raw)
	}

	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/analyses/"+ids[0], nil), http.StatusNoContent)
	if r := h.do(http.MethodGet, "/v1/ai/analyses/"+ids[0], nil); r.status != http.StatusNotFound {
		t.Fatalf("deleted analysis = %d", r.status)
	}
	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/analyses", nil), http.StatusNoContent)
	if left := h.do(http.MethodGet, "/v1/ai/analyses", nil).body["items"].([]any); len(left) != 0 {
		t.Fatalf("after delete all = %v", left)
	}
}

func TestRun_KeyNeverReachesTheClient(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-never-shown-0001")
	h.seedLedger()
	h.fake.Deltas = []string{"ok"}
	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	id := res.events[0].data["analysis_id"].(string)
	for _, path := range []string{"/v1/ai/analyses/" + id, "/v1/ai/analyses", "/v1/ai/settings"} {
		if r := h.do(http.MethodGet, path, nil); strings.Contains(r.raw, "never-shown") {
			t.Fatalf("%s leaks the key", path)
		}
	}
	if last := h.factory.Configs[len(h.factory.Configs)-1]; last.APIKey != "sk-never-shown-0001" {
		t.Fatalf("the provider must receive the decrypted key, got %q", last.APIKey)
	}
}
