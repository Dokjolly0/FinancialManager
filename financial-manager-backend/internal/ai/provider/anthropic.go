package provider

import (
	"context"
	"encoding/json"
	"strings"
)

// anthropicProvider implements the Messages API with streaming
// (POST /v1/messages, stream: true).
type anthropicProvider struct {
	baseHTTP
}

const anthropicVersion = "2023-06-01"

func (p *anthropicProvider) headers() map[string]string {
	return map[string]string{"x-api-key": p.apiKey, "anthropic-version": anthropicVersion}
}

type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type anthropicRequest struct {
	Model       string             `json:"model"`
	MaxTokens   int                `json:"max_tokens"`
	System      string             `json:"system,omitempty"`
	Messages    []anthropicMessage `json:"messages"`
	Temperature *float64           `json:"temperature,omitempty"`
	Stream      bool               `json:"stream"`
}

type anthropicUsage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

// anthropicEvent covers the fields used across the event types:
// message_start, content_block_delta, message_delta and error.
type anthropicEvent struct {
	Type    string `json:"type"`
	Message struct {
		Usage anthropicUsage `json:"usage"`
	} `json:"message"`
	Delta struct {
		Type       string `json:"type"`
		Text       string `json:"text"`
		StopReason string `json:"stop_reason"`
	} `json:"delta"`
	Usage anthropicUsage `json:"usage"`
	Error struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

func (p *anthropicProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	body := anthropicRequest{
		Model: req.Model, MaxTokens: req.MaxTokens, System: req.System,
		Temperature: req.Temperature, Stream: true,
	}
	for _, m := range req.Messages {
		body.Messages = append(body.Messages, anthropicMessage{Role: string(m.Role), Content: m.Content})
	}

	var result StreamResult
	err := p.postStream(ctx, p.baseURL+"/v1/messages", p.headers(), body, func(ev sseEvent) error {
		var e anthropicEvent
		if err := json.Unmarshal([]byte(ev.Data), &e); err != nil {
			return &Error{Kind: ErrBadResponse, Message: "unreadable stream event"}
		}
		switch e.Type {
		case "message_start":
			result.InputTokens = e.Message.Usage.InputTokens
			result.OutputTokens = e.Message.Usage.OutputTokens
		case "content_block_delta":
			if e.Delta.Type == "text_delta" && e.Delta.Text != "" {
				return onDelta(e.Delta.Text)
			}
		case "message_delta":
			if e.Usage.OutputTokens > 0 {
				result.OutputTokens = e.Usage.OutputTokens
			}
			if e.Delta.StopReason == "max_tokens" {
				result.Truncated = true
			}
		case "message_stop":
			return errStreamDone
		case "error":
			return anthropicStreamError(e.Error.Type, e.Error.Message)
		}
		return nil
	})
	return result, err
}

// anthropicStreamError classifies an error event sent after the stream
// started (the HTTP status was already 200).
func anthropicStreamError(errType, message string) *Error {
	kind := ErrBadResponse
	switch errType {
	case "overloaded_error", "api_error":
		kind = ErrUnavailable
	case "rate_limit_error":
		kind = ErrRateLimited
	case "authentication_error", "permission_error":
		kind = ErrInvalidKey
	case "not_found_error":
		kind = ErrModelNotFound
	case "invalid_request_error":
		if strings.Contains(strings.ToLower(message), "too long") {
			kind = ErrContextTooLong
		}
	}
	return &Error{Kind: kind, Message: sanitizeMessage(message)}
}

func (p *anthropicProvider) ListModels(ctx context.Context) ([]ModelInfo, error) {
	var resp struct {
		Data []struct {
			ID          string `json:"id"`
			DisplayName string `json:"display_name"`
		} `json:"data"`
	}
	if err := p.getJSON(ctx, p.baseURL+"/v1/models?limit=1000", p.headers(), &resp); err != nil {
		return nil, err
	}
	models := make([]ModelInfo, 0, len(resp.Data))
	for _, m := range resp.Data {
		models = append(models, ModelInfo{ID: m.ID, DisplayName: m.DisplayName})
	}
	return models, nil
}
