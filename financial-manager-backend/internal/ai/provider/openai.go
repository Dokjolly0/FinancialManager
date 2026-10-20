package provider

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"sort"
	"strings"
)

// openAIProvider implements Chat Completions with streaming, for OpenAI
// itself (native) and for OpenAI-compatible servers.
type openAIProvider struct {
	baseHTTP
	// native is true for api.openai.com, which wants max_completion_tokens
	// (reasoning models reject max_tokens) and whose model list needs
	// filtering to chat models.
	native bool
}

func (p *openAIProvider) headers() map[string]string {
	if p.apiKey == "" {
		return map[string]string{}
	}
	return map[string]string{"Authorization": "Bearer " + p.apiKey}
}

type openAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIStreamOptions struct {
	IncludeUsage bool `json:"include_usage"`
}

type openAIRequest struct {
	Model               string               `json:"model"`
	Messages            []openAIMessage      `json:"messages"`
	Stream              bool                 `json:"stream"`
	StreamOptions       *openAIStreamOptions `json:"stream_options,omitempty"`
	MaxTokens           int                  `json:"max_tokens,omitempty"`
	MaxCompletionTokens int                  `json:"max_completion_tokens,omitempty"`
	Temperature         *float64             `json:"temperature,omitempty"`
}

type openAIChunk struct {
	Choices []struct {
		Delta struct {
			Content string `json:"content"`
		} `json:"delta"`
		FinishReason string `json:"finish_reason"`
	} `json:"choices"`
	Usage *struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
	} `json:"usage"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Code    any    `json:"code"`
	} `json:"error"`
}

func (p *openAIProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	body := openAIRequest{
		Model: req.Model, Stream: true, Temperature: req.Temperature,
		StreamOptions: &openAIStreamOptions{IncludeUsage: true},
	}
	if p.native {
		body.MaxCompletionTokens = req.MaxTokens
	} else {
		body.MaxTokens = req.MaxTokens
	}
	if req.System != "" {
		body.Messages = append(body.Messages, openAIMessage{Role: "system", Content: req.System})
	}
	for _, m := range req.Messages {
		body.Messages = append(body.Messages, openAIMessage{Role: string(m.Role), Content: m.Content})
	}

	result, started, err := p.stream(ctx, body, onDelta)
	// Some compatible servers reject stream_options with a 400/422; retry
	// once without it (usage is then unknown) unless text already flowed.
	var pe *Error
	if !p.native && !started && errors.As(err, &pe) &&
		(pe.Status == http.StatusBadRequest || pe.Status == http.StatusUnprocessableEntity) &&
		strings.Contains(strings.ToLower(pe.Message), "stream_options") {
		body.StreamOptions = nil
		result, _, err = p.stream(ctx, body, onDelta)
	}
	return result, err
}

func (p *openAIProvider) stream(ctx context.Context, body openAIRequest, onDelta func(string) error) (StreamResult, bool, error) {
	var result StreamResult
	started := false
	err := p.postStream(ctx, p.baseURL+"/chat/completions", p.headers(), body, func(ev sseEvent) error {
		if strings.TrimSpace(ev.Data) == "[DONE]" {
			return errStreamDone
		}
		var chunk openAIChunk
		if err := json.Unmarshal([]byte(ev.Data), &chunk); err != nil {
			return &Error{Kind: ErrBadResponse, Message: "unreadable stream event"}
		}
		if chunk.Error != nil {
			return classifyHTTP(0, []byte(`{"error":{"message":`+quoteJSON(chunk.Error.Message+" "+chunk.Error.Type)+`}}`))
		}
		if chunk.Usage != nil {
			result.InputTokens = chunk.Usage.PromptTokens
			result.OutputTokens = chunk.Usage.CompletionTokens
		}
		for _, c := range chunk.Choices {
			if c.FinishReason == "length" {
				result.Truncated = true
			}
			if c.Delta.Content != "" {
				started = true
				if err := onDelta(c.Delta.Content); err != nil {
					return err
				}
			}
		}
		return nil
	})
	return result, started, err
}

func quoteJSON(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

// nonChatModelMarkers excludes the OpenAI models that cannot chat.
var nonChatModelMarkers = []string{
	"embedding", "whisper", "tts", "dall-e", "moderation", "davinci", "babbage",
	"audio", "realtime", "transcribe", "image", "search", "computer-use", "sora",
}

func (p *openAIProvider) ListModels(ctx context.Context) ([]ModelInfo, error) {
	var resp struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := p.getJSON(ctx, p.baseURL+"/models", p.headers(), &resp); err != nil {
		return nil, err
	}
	models := make([]ModelInfo, 0, len(resp.Data))
	for _, m := range resp.Data {
		if p.native && containsAny(strings.ToLower(m.ID), nonChatModelMarkers...) {
			continue
		}
		models = append(models, ModelInfo{ID: m.ID, DisplayName: m.ID})
	}
	sort.Slice(models, func(i, j int) bool { return models[i].ID < models[j].ID })
	return models, nil
}
