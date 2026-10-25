package provider

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"testing"
)

var searchTool = Tool{
	Name: "search_transactions", Description: "Search the user's transactions.",
	Schema: json.RawMessage(`{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}`),
}

// toolRequest is a conversation after one round of tool use: the model's
// call, its result, and the request offering the tool again.
var toolRequest = ChatRequest{
	Model: "m1", System: "sys", MaxTokens: 100, Tools: []Tool{searchTool},
	Messages: []Message{
		{Role: RoleUser, Content: "Quando ho pagato l'assicurazione?"},
		{Role: RoleAssistant, Content: "Cerco.", ToolCalls: []ToolCall{
			{ID: "call_1", Name: "search_transactions", Args: json.RawMessage(`{"query":"assicurazione"}`), Signature: "sig-1"},
		}},
		{Role: RoleUser, ToolResults: []ToolResult{{CallID: "call_1", Name: "search_transactions", Content: "2024-06-01 | 480.00"}}},
	},
}

func sameJSON(t *testing.T, got any, want string) {
	t.Helper()
	g, _ := json.Marshal(got)
	var a, b any
	_ = json.Unmarshal(g, &a)
	if err := json.Unmarshal([]byte(want), &b); err != nil {
		t.Fatal(err)
	}
	ga, _ := json.Marshal(a)
	gb, _ := json.Marshal(b)
	if string(ga) != string(gb) {
		t.Errorf("got  %s\nwant %s", ga, gb)
	}
}

func TestAnthropic_ToolCalls(t *testing.T) {
	stream := strings.Join([]string{
		`data: {"type":"message_start","message":{"usage":{"input_tokens":30,"output_tokens":1}}}`, "",
		`data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}`, "",
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Cerco."}}`, "",
		`data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_1","name":"search_transactions","input":{}}}`, "",
		`data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"query\":"}}`, "",
		`data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"assic\"}"}}`, "",
		`data: {"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_2","name":"sum_transactions","input":{}}}`, "",
		`data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":12}}`, "",
		`data: {"type":"message_stop"}`, "",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, _ := testFactory(KindAnthropic, srv.URL).New(Config{Kind: KindAnthropic, APIKey: "k"})

	text, res, err := collect(t, p, toolRequest)
	if err != nil || text != "Cerco." || res.Truncated {
		t.Fatalf("text = %q res = %+v err = %v", text, res, err)
	}
	if len(res.ToolCalls) != 2 || res.ToolCalls[0].ID != "toolu_1" || string(res.ToolCalls[0].Args) != `{"query":"assic"}` ||
		res.ToolCalls[1].Name != "sum_transactions" || string(res.ToolCalls[1].Args) != "{}" {
		t.Fatalf("tool calls = %+v", res.ToolCalls)
	}
	sameJSON(t, rec.body["tools"], `[{"name":"search_transactions","description":"Search the user's transactions.",
		"input_schema":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}]`)
	sameJSON(t, rec.body["messages"], `[
		{"role":"user","content":"Quando ho pagato l'assicurazione?"},
		{"role":"assistant","content":[{"type":"text","text":"Cerco."},
			{"type":"tool_use","id":"call_1","name":"search_transactions","input":{"query":"assicurazione"}}]},
		{"role":"user","content":[{"type":"tool_result","tool_use_id":"call_1","content":"2024-06-01 | 480.00"}]}]`)
}

func TestOpenAI_ToolCalls(t *testing.T) {
	stream := strings.Join([]string{
		`data: {"choices":[{"delta":{"role":"assistant","tool_calls":[{"index":0,"id":"call_a","type":"function","function":{"name":"search_transactions","arguments":""}}]}}]}`, "",
		`data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"query\""}}]}}]}`, "",
		`data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":":\"bollo\"}"}}]}}]}`, "",
		`data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}`, "",
		`data: {"choices":[],"usage":{"prompt_tokens":40,"completion_tokens":9}}`, "",
		"data: [DONE]", "",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "sk-test-123456"})

	text, res, err := collect(t, p, toolRequest)
	if err != nil || text != "" || res.InputTokens != 40 {
		t.Fatalf("text = %q res = %+v err = %v", text, res, err)
	}
	if len(res.ToolCalls) != 1 || res.ToolCalls[0].ID != "call_a" || res.ToolCalls[0].Name != "search_transactions" ||
		string(res.ToolCalls[0].Args) != `{"query":"bollo"}` {
		t.Fatalf("tool calls = %+v", res.ToolCalls)
	}
	sameJSON(t, rec.body["tools"], `[{"type":"function","function":{"name":"search_transactions",
		"description":"Search the user's transactions.",
		"parameters":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}}]`)
	sameJSON(t, rec.body["messages"], `[
		{"role":"system","content":"sys"},
		{"role":"user","content":"Quando ho pagato l'assicurazione?"},
		{"role":"assistant","content":"Cerco.","tool_calls":[{"id":"call_1","type":"function",
			"function":{"name":"search_transactions","arguments":"{\"query\":\"assicurazione\"}"}}]},
		{"role":"tool","content":"2024-06-01 | 480.00","tool_call_id":"call_1"}]`)
}

func TestOpenAICompatible_ToolsUnsupported(t *testing.T) {
	body := `{"error":{"message":"this model does not support tools"}}`
	srv := sseServer(t, http.StatusBadRequest, body, nil)
	p, _ := testFactory(KindOpenAICompatible, srv.URL).New(Config{Kind: KindOpenAICompatible, BaseURL: srv.URL})

	_, _, err := collect(t, p, toolRequest)
	var pe *Error
	if !errors.As(err, &pe) || pe.Kind != ErrToolsUnsupported {
		t.Fatalf("with tools: err = %v, want TOOLS_UNSUPPORTED", err)
	}
	// The same refusal without tools is an ordinary error.
	_, _, err = collect(t, p, testRequest)
	if !errors.As(err, &pe) || pe.Kind == ErrToolsUnsupported {
		t.Fatalf("without tools: err = %v", err)
	}
}

func TestGemini_FunctionCalls(t *testing.T) {
	stream := strings.Join([]string{
		`data: {"candidates":[{"content":{"parts":[{"text":"Cerco. "},{"functionCall":{"name":"search_transactions","args":{"query":"vps"}},"thoughtSignature":"sig-x"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":50,"candidatesTokenCount":6}}`,
		"",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, _ := testFactory(KindGemini, srv.URL).New(Config{Kind: KindGemini, APIKey: "AIza-test"})

	text, res, err := collect(t, p, toolRequest)
	if err != nil || text != "Cerco. " {
		t.Fatalf("text = %q err = %v", text, err)
	}
	if len(res.ToolCalls) != 1 || res.ToolCalls[0].ID != "call_1" || res.ToolCalls[0].Signature != "sig-x" ||
		string(res.ToolCalls[0].Args) != `{"query":"vps"}` {
		t.Fatalf("tool calls = %+v", res.ToolCalls)
	}
	sameJSON(t, rec.body["tools"], `[{"functionDeclarations":[{"name":"search_transactions",
		"description":"Search the user's transactions.",
		"parameters":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}]}]`)
	sameJSON(t, rec.body["contents"], `[
		{"role":"user","parts":[{"text":"Quando ho pagato l'assicurazione?"}]},
		{"role":"model","parts":[{"text":"Cerco."},
			{"functionCall":{"name":"search_transactions","args":{"query":"assicurazione"}},"thoughtSignature":"sig-1"}]},
		{"role":"user","parts":[{"functionResponse":{"name":"search_transactions","response":{"content":"2024-06-01 | 480.00"}}}]}]`)
}

// Requests without tools keep the shape they had before tools existed.
func TestNoTools_RequestsUnchanged(t *testing.T) {
	for _, kind := range []Kind{KindAnthropic, KindOpenAI, KindGemini} {
		var rec recorded
		srv := sseServer(t, http.StatusOK, "data: [DONE]\n\n", &rec)
		p, _ := testFactory(kind, srv.URL).New(Config{Kind: kind, APIKey: "AIza-test-key"})
		_, _, _ = collect(t, p, testRequest)
		if _, ok := rec.body["tools"]; ok {
			t.Errorf("%s: tools sent without tools", kind)
		}
		raw, _ := json.Marshal(rec.body)
		for _, field := range []string{"tool_calls", "tool_use", "functionCall", "tool_call_id"} {
			if strings.Contains(string(raw), field) {
				t.Errorf("%s: %s in a plain request: %s", kind, field, raw)
			}
		}
	}
}
