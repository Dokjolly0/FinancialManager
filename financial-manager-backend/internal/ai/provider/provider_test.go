package provider

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// sseServer answers every request with status and body, recording the
// last request.
type recorded struct {
	path    string
	query   string
	headers http.Header
	body    map[string]any
}

func sseServer(t *testing.T, status int, body string, rec *recorded) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if rec != nil {
			rec.path, rec.query, rec.headers = r.URL.Path, r.URL.RawQuery, r.Header.Clone()
			raw, _ := io.ReadAll(r.Body)
			rec.body = map[string]any{}
			_ = json.Unmarshal(raw, &rec.body)
		}
		if status == http.StatusOK && strings.Contains(body, "data:") {
			w.Header().Set("Content-Type", "text/event-stream")
		} else {
			w.Header().Set("Content-Type", "application/json")
		}
		w.WriteHeader(status)
		_, _ = io.WriteString(w, body)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func testFactory(kind Kind, url string) *HTTPFactory {
	return NewHTTPFactory(BaseURLPolicy{AllowPrivate: true}, 5*time.Second).WithNativeBaseURL(kind, url)
}

func collect(t *testing.T, p Provider, req ChatRequest) (string, StreamResult, error) {
	t.Helper()
	var sb strings.Builder
	res, err := p.Stream(context.Background(), req, func(s string) error {
		sb.WriteString(s)
		return nil
	})
	return sb.String(), res, err
}

var testRequest = ChatRequest{
	Model: "m1", System: "sys", MaxTokens: 100,
	Messages: []Message{{Role: RoleUser, Content: "hi"}, {Role: RoleAssistant, Content: "hello"}, {Role: RoleUser, Content: "again"}},
}

func TestAnthropic_Stream(t *testing.T) {
	stream := strings.Join([]string{
		"event: message_start",
		`data: {"type":"message_start","message":{"usage":{"input_tokens":42,"output_tokens":1}}}`,
		"",
		"event: ping",
		`data: {"type":"ping"}`,
		"",
		"event: content_block_delta",
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Ciao "}}`,
		"",
		"event: content_block_delta",
		`data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"mondo"}}`,
		"",
		"event: message_delta",
		`data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"},"usage":{"output_tokens":7}}`,
		"",
		"event: message_stop",
		`data: {"type":"message_stop"}`,
		"",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, err := testFactory(KindAnthropic, srv.URL).New(Config{Kind: KindAnthropic, APIKey: "sk-ant-test"})
	if err != nil {
		t.Fatal(err)
	}

	text, res, err := collect(t, p, testRequest)
	if err != nil {
		t.Fatalf("Stream() error = %v", err)
	}
	if text != "Ciao mondo" {
		t.Fatalf("text = %q", text)
	}
	if res.InputTokens != 42 || res.OutputTokens != 7 || !res.Truncated {
		t.Fatalf("result = %+v", res)
	}
	if rec.path != "/v1/messages" || rec.headers.Get("x-api-key") != "sk-ant-test" || rec.headers.Get("anthropic-version") == "" {
		t.Fatalf("request path/headers = %s %v", rec.path, rec.headers)
	}
	if rec.body["system"] != "sys" || rec.body["stream"] != true || rec.body["max_tokens"] != float64(100) {
		t.Fatalf("request body = %v", rec.body)
	}
	if msgs := rec.body["messages"].([]any); len(msgs) != 3 {
		t.Fatalf("messages = %v", msgs)
	}
}

func TestAnthropic_ErrorEventMidStream(t *testing.T) {
	stream := "event: content_block_delta\n" +
		`data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"part"}}` + "\n\n" +
		"event: error\n" +
		`data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}` + "\n\n"
	srv := sseServer(t, http.StatusOK, stream, nil)
	p, _ := testFactory(KindAnthropic, srv.URL).New(Config{Kind: KindAnthropic, APIKey: "k"})

	text, _, err := collect(t, p, testRequest)
	var pe *Error
	if !errors.As(err, &pe) || pe.Kind != ErrUnavailable {
		t.Fatalf("err = %v, want UNAVAILABLE", err)
	}
	if text != "part" {
		t.Fatalf("text before the error = %q", text)
	}
}

func TestOpenAI_StreamNative(t *testing.T) {
	stream := strings.Join([]string{
		`data: {"choices":[{"delta":{"role":"assistant"}}]}`,
		"",
		`data: {"choices":[{"delta":{"content":"Uno"}}]}`,
		"",
		`data: {"choices":[{"delta":{"content":" due"},"finish_reason":"stop"}]}`,
		"",
		`data: {"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":3}}`,
		"",
		"data: [DONE]",
		"",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "sk-test"})

	text, res, err := collect(t, p, testRequest)
	if err != nil {
		t.Fatalf("Stream() error = %v", err)
	}
	if text != "Uno due" || res.InputTokens != 10 || res.OutputTokens != 3 || res.Truncated {
		t.Fatalf("text = %q result = %+v", text, res)
	}
	if rec.path != "/chat/completions" || rec.headers.Get("Authorization") != "Bearer sk-test" {
		t.Fatalf("path = %s auth = %q", rec.path, rec.headers.Get("Authorization"))
	}
	if rec.body["max_completion_tokens"] != float64(100) || rec.body["max_tokens"] != nil {
		t.Fatalf("native OpenAI must send max_completion_tokens only: %v", rec.body)
	}
	msgs := rec.body["messages"].([]any)
	if first := msgs[0].(map[string]any); first["role"] != "system" || first["content"] != "sys" {
		t.Fatalf("first message = %v, want the system prompt", first)
	}
}

func TestOpenAICompatible_NoKeyAndMaxTokens(t *testing.T) {
	var rec recorded
	srv := sseServer(t, http.StatusOK, "data: {\"choices\":[{\"delta\":{\"content\":\"ok\"},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n", &rec)
	p, err := testFactory(KindOpenAI, "").New(Config{Kind: KindOpenAICompatible, BaseURL: srv.URL + "/v1/"})
	if err != nil {
		t.Fatal(err)
	}

	text, res, err := collect(t, p, testRequest)
	if err != nil || text != "ok" || !res.Truncated {
		t.Fatalf("text = %q res = %+v err = %v", text, res, err)
	}
	if rec.path != "/v1/chat/completions" {
		t.Fatalf("path = %s (trailing slash must be trimmed)", rec.path)
	}
	if rec.headers.Get("Authorization") != "" {
		t.Fatal("no Authorization header expected without a key")
	}
	if rec.body["max_tokens"] != float64(100) || rec.body["max_completion_tokens"] != nil {
		t.Fatalf("compatible servers get max_tokens: %v", rec.body)
	}
}

func TestOpenAICompatible_RetriesWithoutStreamOptions(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		raw, _ := io.ReadAll(r.Body)
		if strings.Contains(string(raw), "stream_options") {
			w.WriteHeader(http.StatusUnprocessableEntity)
			_, _ = io.WriteString(w, `{"error":{"message":"Extra inputs are not permitted: stream_options"}}`)
			return
		}
		_, _ = io.WriteString(w, "data: {\"choices\":[{\"delta\":{\"content\":\"ok\"}}]}\n\ndata: [DONE]\n\n")
	}))
	defer srv.Close()
	p, _ := testFactory(KindOpenAI, "").New(Config{Kind: KindOpenAICompatible, BaseURL: srv.URL})

	text, _, err := collect(t, p, testRequest)
	if err != nil || text != "ok" || calls != 2 {
		t.Fatalf("text = %q err = %v calls = %d", text, err, calls)
	}
}

func TestGemini_Stream(t *testing.T) {
	stream := strings.Join([]string{
		`data: {"candidates":[{"content":{"parts":[{"text":"pensiero","thought":true}]}}]}`,
		"",
		`data: {"candidates":[{"content":{"parts":[{"text":"Ri"}]}}],"usageMetadata":{"promptTokenCount":20,"candidatesTokenCount":1}}`,
		"",
		`data: {"candidates":[{"content":{"parts":[{"text":"sposta"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":20,"candidatesTokenCount":5,"thoughtsTokenCount":4}}`,
		"",
	}, "\n")
	var rec recorded
	srv := sseServer(t, http.StatusOK, stream, &rec)
	p, _ := testFactory(KindGemini, srv.URL).New(Config{Kind: KindGemini, APIKey: "AIza-test"})

	req := testRequest
	req.Model = "models/gemini-test"
	text, res, err := collect(t, p, req)
	if err != nil {
		t.Fatalf("Stream() error = %v", err)
	}
	if text != "Risposta" || res.InputTokens != 20 || res.OutputTokens != 9 {
		t.Fatalf("text = %q result = %+v", text, res)
	}
	if rec.path != "/v1beta/models/gemini-test:streamGenerateContent" || rec.query != "alt=sse" {
		t.Fatalf("path = %s?%s", rec.path, rec.query)
	}
	if rec.headers.Get("x-goog-api-key") != "AIza-test" {
		t.Fatal("missing x-goog-api-key")
	}
	contents := rec.body["contents"].([]any)
	if second := contents[1].(map[string]any); second["role"] != "model" {
		t.Fatalf("assistant messages must use role model: %v", second)
	}
	if rec.body["systemInstruction"] == nil {
		t.Fatal("missing systemInstruction")
	}
}

func TestGemini_SafetyBlock(t *testing.T) {
	srv := sseServer(t, http.StatusOK, `data: {"candidates":[{"content":{"parts":[]},"finishReason":"SAFETY"}]}`+"\n\n", nil)
	p, _ := testFactory(KindGemini, srv.URL).New(Config{Kind: KindGemini, APIKey: "k"})
	_, _, err := collect(t, p, testRequest)
	var pe *Error
	if !errors.As(err, &pe) || pe.Kind != ErrContentBlocked {
		t.Fatalf("err = %v, want CONTENT_BLOCKED", err)
	}
}

func TestStream_HTTPErrorClassification(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
		want   ErrorKind
	}{
		{"unauthorized", 401, `{"error":{"message":"Incorrect API key provided: sk-abcdefghijklmnop"}}`, ErrInvalidKey},
		{"gemini bad key", 400, `{"error":{"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}`, ErrInvalidKey},
		{"rate limited", 429, `{"error":{"message":"Rate limit reached"}}`, ErrRateLimited},
		{"openai quota", 429, `{"error":{"message":"You exceeded your current quota","code":"insufficient_quota"}}`, ErrQuotaExceeded},
		{"anthropic credit", 400, `{"error":{"type":"invalid_request_error","message":"Your credit balance is too low"}}`, ErrQuotaExceeded},
		{"payment required", 402, `{"error":"Insufficient credits"}`, ErrQuotaExceeded},
		{"context", 400, `{"error":{"message":"This model's maximum context length is 8192 tokens","code":"context_length_exceeded"}}`, ErrContextTooLong},
		{"anthropic too long", 400, `{"error":{"message":"prompt is too long: 250000 tokens > 200000 maximum"}}`, ErrContextTooLong},
		{"model missing", 404, `{"error":{"message":"The model 'x' does not exist"}}`, ErrModelNotFound},
		{"overloaded", 529, `{"error":{"message":"Overloaded"}}`, ErrUnavailable},
		{"server error", 500, `oops`, ErrUnavailable},
		{"bad request", 400, `{"error":{"message":"messages: field required"}}`, ErrBadResponse},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			srv := sseServer(t, c.status, c.body, nil)
			p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "k"})
			_, _, err := collect(t, p, testRequest)
			var pe *Error
			if !errors.As(err, &pe) {
				t.Fatalf("err = %v, want *Error", err)
			}
			if pe.Kind != c.want || pe.Status != c.status {
				t.Fatalf("kind/status = %s/%d, want %s/%d", pe.Kind, pe.Status, c.want, c.status)
			}
			if strings.Contains(pe.Message, "sk-abcdefghijklmnop") {
				t.Fatalf("message leaks the key: %q", pe.Message)
			}
		})
	}
}

func TestStream_CallerCancellation(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		flusher := w.(http.Flusher)
		for i := 0; ; i++ {
			if _, err := io.WriteString(w, "data: {\"choices\":[{\"delta\":{\"content\":\"x\"}}]}\n\n"); err != nil {
				return
			}
			flusher.Flush()
			select {
			case <-r.Context().Done():
				return
			case <-time.After(10 * time.Millisecond):
			}
		}
	}))
	defer srv.Close()
	p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "k"})

	ctx, cancel := context.WithCancel(context.Background())
	received := 0
	_, err := p.Stream(ctx, testRequest, func(string) error {
		received++
		if received == 3 {
			cancel()
		}
		return nil
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("err = %v, want context.Canceled", err)
	}
}

func TestStream_OnDeltaErrorStopsStream(t *testing.T) {
	srv := sseServer(t, http.StatusOK, "data: {\"choices\":[{\"delta\":{\"content\":\"a\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"b\"}}]}\n\n", nil)
	p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "k"})
	stop := errors.New("client gone")
	calls := 0
	_, err := p.Stream(context.Background(), testRequest, func(string) error {
		calls++
		return stop
	})
	if !errors.Is(err, stop) || calls != 1 {
		t.Fatalf("err = %v calls = %d", err, calls)
	}
}

func TestStream_IdleTimeout(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "data: {\"choices\":[{\"delta\":{\"content\":\"x\"}}]}\n\n")
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	}))
	defer srv.Close()
	f := NewHTTPFactory(BaseURLPolicy{AllowPrivate: true}, 100*time.Millisecond).WithNativeBaseURL(KindOpenAI, srv.URL)
	p, _ := f.New(Config{Kind: KindOpenAI, APIKey: "k"})

	start := time.Now()
	_, _, err := collect(t, p, testRequest)
	var pe *Error
	if !errors.As(err, &pe) || pe.Kind != ErrTimeout {
		t.Fatalf("err = %v, want TIMEOUT", err)
	}
	if time.Since(start) > 3*time.Second {
		t.Fatal("idle watchdog did not fire")
	}
}

func TestListModels(t *testing.T) {
	t.Run("anthropic", func(t *testing.T) {
		srv := sseServer(t, 200, `{"data":[{"id":"claude-x","display_name":"Claude X"}]}`, nil)
		p, _ := testFactory(KindAnthropic, srv.URL).New(Config{Kind: KindAnthropic, APIKey: "k"})
		models, err := p.ListModels(context.Background())
		if err != nil || len(models) != 1 || models[0].DisplayName != "Claude X" {
			t.Fatalf("models = %v err = %v", models, err)
		}
	})
	t.Run("openai filters non-chat models", func(t *testing.T) {
		srv := sseServer(t, 200, `{"data":[{"id":"text-embedding-3-small"},{"id":"gpt-z"},{"id":"whisper-1"},{"id":"gpt-a"}]}`, nil)
		p, _ := testFactory(KindOpenAI, srv.URL).New(Config{Kind: KindOpenAI, APIKey: "k"})
		models, err := p.ListModels(context.Background())
		if err != nil || len(models) != 2 || models[0].ID != "gpt-a" || models[1].ID != "gpt-z" {
			t.Fatalf("models = %v err = %v", models, err)
		}
	})
	t.Run("compatible keeps everything", func(t *testing.T) {
		srv := sseServer(t, 200, `{"data":[{"id":"mistral-embed"},{"id":"mistral-large"}]}`, nil)
		p, _ := testFactory(KindOpenAI, "").New(Config{Kind: KindOpenAICompatible, BaseURL: srv.URL})
		models, err := p.ListModels(context.Background())
		if err != nil || len(models) != 2 {
			t.Fatalf("models = %v err = %v", models, err)
		}
	})
	t.Run("gemini keeps generateContent models", func(t *testing.T) {
		srv := sseServer(t, 200, `{"models":[{"name":"models/gemini-x","displayName":"Gemini X","supportedGenerationMethods":["generateContent","countTokens"]},{"name":"models/embedding-001","supportedGenerationMethods":["embedContent"]}]}`, nil)
		p, _ := testFactory(KindGemini, srv.URL).New(Config{Kind: KindGemini, APIKey: "k"})
		models, err := p.ListModels(context.Background())
		if err != nil || len(models) != 1 || models[0].ID != "gemini-x" {
			t.Fatalf("models = %v err = %v", models, err)
		}
	})
	t.Run("invalid key", func(t *testing.T) {
		srv := sseServer(t, 401, `{"error":{"message":"invalid x-api-key"}}`, nil)
		p, _ := testFactory(KindAnthropic, srv.URL).New(Config{Kind: KindAnthropic, APIKey: "k"})
		_, err := p.ListModels(context.Background())
		var pe *Error
		if !errors.As(err, &pe) || pe.Kind != ErrInvalidKey {
			t.Fatalf("err = %v", err)
		}
	})
}

func TestFactory_RequiresKeyForNativeProviders(t *testing.T) {
	f := NewHTTPFactory(BaseURLPolicy{}, time.Second)
	for _, k := range []Kind{KindAnthropic, KindOpenAI, KindGemini} {
		if _, err := f.New(Config{Kind: k}); err == nil {
			t.Errorf("%s without a key: expected an error", k)
		}
	}
	if _, err := f.New(Config{Kind: "nope", APIKey: "k"}); err == nil {
		t.Error("unknown kind: expected an error")
	}
}

func TestReadSSE_MultiLineDataAndComments(t *testing.T) {
	in := ": comment\r\nevent: a\r\ndata: line1\r\ndata: line2\r\n\r\ndata: tail"
	var got []sseEvent
	err := readSSE(strings.NewReader(in), func(e sseEvent) error {
		got = append(got, e)
		return nil
	})
	if err != nil || len(got) != 2 || got[0].Event != "a" || got[0].Data != "line1\nline2" || got[1].Data != "tail" {
		t.Fatalf("events = %+v err = %v", got, err)
	}
}
