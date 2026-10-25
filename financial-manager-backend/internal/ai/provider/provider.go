// Package provider talks to the LLM providers used by the AI analysis
// (plan.md section 32.5): Anthropic, OpenAI and Google Gemini natively, and
// any "OpenAI-compatible" server (Mistral, Groq, DeepSeek, OpenRouter,
// Ollama...) through a user-supplied base URL.
//
// Every adapter streams: the response text reaches the caller through
// onDelta as it arrives, and the token usage reported by the provider is
// returned at the end. Wire details stay inside each adapter file; callers
// only see the types below and *Error.
package provider

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Kind identifies a provider; the values are stored in the database.
type Kind string

const (
	KindAnthropic        Kind = "anthropic"
	KindOpenAI           Kind = "openai"
	KindGemini           Kind = "gemini"
	KindOpenAICompatible Kind = "openai_compatible"
)

// Valid reports whether k is a supported provider.
func (k Kind) Valid() bool {
	switch k {
	case KindAnthropic, KindOpenAI, KindGemini, KindOpenAICompatible:
		return true
	}
	return false
}

// RequiresBaseURL reports whether the user must supply the base URL.
func (k Kind) RequiresBaseURL() bool { return k == KindOpenAICompatible }

// RequiresAPIKey reports whether the provider cannot work without a key.
// OpenAI-compatible servers may not need one (a local Ollama).
func (k Kind) RequiresAPIKey() bool { return k != KindOpenAICompatible }

// Role is the author of a conversation message.
type Role string

const (
	RoleUser      Role = "user"
	RoleAssistant Role = "assistant"
)

type Message struct {
	Role    Role
	Content string
	// ToolCalls, on an assistant message, are the calls the model made
	// after Content.
	ToolCalls []ToolCall
	// ToolResults, on a user message, answer the previous assistant
	// message's calls, in order.
	ToolResults []ToolResult
}

// Tool is a function the model may call (plan.md section 34.7).
type Tool struct {
	Name        string
	Description string
	// Schema is the JSON Schema of the arguments: an object with
	// properties, kept to the subset every provider accepts (type,
	// description, enum, properties, required).
	Schema json.RawMessage
}

// ToolCall is one call the model made. Args is a JSON object.
type ToolCall struct {
	ID   string
	Name string
	Args json.RawMessage
	// Signature is opaque provider data that must travel back with the
	// call (Gemini's thought signature); empty for the others.
	Signature string
}

// ToolResult answers one ToolCall.
type ToolResult struct {
	CallID  string
	Name    string // Gemini matches results by name
	Content string
}

// ChatRequest is one streamed completion. System is sent the way each
// provider expects it (a top-level field or a leading system message).
type ChatRequest struct {
	Model     string
	System    string
	Messages  []Message
	MaxTokens int
	// Temperature is left to the provider default when nil: reasoning
	// models reject it.
	Temperature *float64
	// Tools, when set, may be called by the model; a request without
	// them is sent exactly as before tools existed.
	Tools []Tool
	// NoMoreToolCalls keeps Tools declared (the history holds calls) but
	// tells the model to answer with text: the last allowed round.
	NoMoreToolCalls bool
}

// StreamResult is what a finished stream reports. Token counts are the
// provider's own, zero when it did not report them.
type StreamResult struct {
	InputTokens  int
	OutputTokens int
	// Truncated is true when generation stopped at MaxTokens.
	Truncated bool
	// ToolCalls are the calls the model made instead of (or after) its
	// text; the caller runs them and sends the results back.
	ToolCalls []ToolCall
}

type ModelInfo struct {
	ID          string
	DisplayName string
}

// Provider is one configured provider account.
type Provider interface {
	// Stream sends the request and calls onDelta with each piece of text,
	// in order. An error returned by onDelta stops the stream and is
	// returned as is. A cancelled ctx returns ctx.Err().
	Stream(ctx context.Context, req ChatRequest, onDelta func(text string) error) (StreamResult, error)
	// ListModels returns the models the account can use for chat.
	ListModels(ctx context.Context) ([]ModelInfo, error)
}

// Config selects and authenticates a provider. BaseURL is only read for
// KindOpenAICompatible; native providers use fixed endpoints.
type Config struct {
	Kind    Kind
	BaseURL string
	APIKey  string
}

// Factory builds providers. The service depends on this interface so tests
// can substitute a scripted provider.
type Factory interface {
	New(cfg Config) (Provider, error)
}

// Default endpoints of the native providers.
const (
	DefaultAnthropicBaseURL = "https://api.anthropic.com"
	DefaultOpenAIBaseURL    = "https://api.openai.com/v1"
	DefaultGeminiBaseURL    = "https://generativelanguage.googleapis.com"
)

// HTTPFactory builds the real adapters, all sharing one SSRF-safe client.
type HTTPFactory struct {
	client      *http.Client
	policy      BaseURLPolicy
	idleTimeout time.Duration
	// nativeBaseURLs overrides the fixed endpoints; only tests set it.
	nativeBaseURLs map[Kind]string
}

// NewHTTPFactory builds a factory. idleTimeout ends a stream that goes
// silent for that long (no bytes at all from the provider).
func NewHTTPFactory(policy BaseURLPolicy, idleTimeout time.Duration) *HTTPFactory {
	return &HTTPFactory{
		client:      NewHTTPClient(policy, idleTimeout),
		policy:      policy,
		idleTimeout: idleTimeout,
	}
}

// WithNativeBaseURL points a native provider at another endpoint. For
// tests only (httptest servers).
func (f *HTTPFactory) WithNativeBaseURL(kind Kind, baseURL string) *HTTPFactory {
	if f.nativeBaseURLs == nil {
		f.nativeBaseURLs = map[Kind]string{}
	}
	f.nativeBaseURLs[kind] = baseURL
	return f
}

func (f *HTTPFactory) nativeBaseURL(kind Kind, def string) string {
	if u, ok := f.nativeBaseURLs[kind]; ok {
		return u
	}
	return def
}

func (f *HTTPFactory) New(cfg Config) (Provider, error) {
	if cfg.Kind.RequiresAPIKey() && cfg.APIKey == "" {
		return nil, fmt.Errorf("provider %s: API key required", cfg.Kind)
	}
	base := baseHTTP{client: f.client, apiKey: cfg.APIKey, idleTimeout: f.idleTimeout}
	switch cfg.Kind {
	case KindAnthropic:
		base.baseURL = f.nativeBaseURL(cfg.Kind, DefaultAnthropicBaseURL)
		return &anthropicProvider{baseHTTP: base}, nil
	case KindOpenAI:
		base.baseURL = f.nativeBaseURL(cfg.Kind, DefaultOpenAIBaseURL)
		return &openAIProvider{baseHTTP: base, native: true}, nil
	case KindGemini:
		base.baseURL = f.nativeBaseURL(cfg.Kind, DefaultGeminiBaseURL)
		return &geminiProvider{baseHTTP: base}, nil
	case KindOpenAICompatible:
		normalized, err := f.policy.ValidateBaseURL(cfg.BaseURL)
		if err != nil {
			return nil, err
		}
		base.baseURL = normalized
		return &openAIProvider{baseHTTP: base}, nil
	}
	return nil, fmt.Errorf("unsupported provider %q", cfg.Kind)
}
