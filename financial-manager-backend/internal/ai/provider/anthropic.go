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

// anthropicMessage's Content is a string, or content blocks when the
// message carries tool calls or results.
type anthropicMessage struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

type anthropicBlock struct {
	Type      string          `json:"type"`
	Text      string          `json:"text,omitempty"`
	ID        string          `json:"id,omitempty"`
	Name      string          `json:"name,omitempty"`
	Input     json.RawMessage `json:"input,omitempty"`
	ToolUseID string          `json:"tool_use_id,omitempty"`
	Content   string          `json:"content,omitempty"`
}

type anthropicTool struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	InputSchema json.RawMessage `json:"input_schema"`
}

type anthropicRequest struct {
	Model       string             `json:"model"`
	MaxTokens   int                `json:"max_tokens"`
	System      string             `json:"system,omitempty"`
	Messages    []anthropicMessage `json:"messages"`
	Temperature *float64           `json:"temperature,omitempty"`
	Tools       []anthropicTool    `json:"tools,omitempty"`
	ToolChoice  *anthropicChoice   `json:"tool_choice,omitempty"`
	Stream      bool               `json:"stream"`
}

type anthropicChoice struct {
	Type string `json:"type"`
}

type anthropicUsage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
}

// anthropicEvent covers the fields used across the event types:
// message_start, content_block_start, content_block_delta, message_delta
// and error.
type anthropicEvent struct {
	Type    string `json:"type"`
	Index   int    `json:"index"`
	Message struct {
		Usage anthropicUsage `json:"usage"`
	} `json:"message"`
	ContentBlock struct {
		Type string `json:"type"`
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"content_block"`
	Delta struct {
		Type        string `json:"type"`
		Text        string `json:"text"`
		PartialJSON string `json:"partial_json"`
		StopReason  string `json:"stop_reason"`
	} `json:"delta"`
	Usage anthropicUsage `json:"usage"`
	Error struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

// anthropicMessages turns the conversation into Messages API messages:
// plain text as a string, tool calls as tool_use blocks after the text,
// results as tool_result blocks.
func anthropicMessages(messages []Message) []anthropicMessage {
	out := make([]anthropicMessage, 0, len(messages))
	for _, m := range messages {
		if len(m.ToolCalls) == 0 && len(m.ToolResults) == 0 {
			out = append(out, anthropicMessage{Role: string(m.Role), Content: m.Content})
			continue
		}
		var blocks []anthropicBlock
		if m.Content != "" {
			blocks = append(blocks, anthropicBlock{Type: "text", Text: m.Content})
		}
		for _, c := range m.ToolCalls {
			blocks = append(blocks, anthropicBlock{Type: "tool_use", ID: c.ID, Name: c.Name, Input: argsOrEmpty(c.Args)})
		}
		for _, r := range m.ToolResults {
			blocks = append(blocks, anthropicBlock{Type: "tool_result", ToolUseID: r.CallID, Content: r.Content})
		}
		out = append(out, anthropicMessage{Role: string(m.Role), Content: blocks})
	}
	return out
}

// argsOrEmpty is a call's arguments, "{}" when the model sent none.
func argsOrEmpty(args json.RawMessage) json.RawMessage {
	if len(strings.TrimSpace(string(args))) == 0 {
		return json.RawMessage("{}")
	}
	return args
}

func (p *anthropicProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	body := anthropicRequest{
		Model: req.Model, MaxTokens: req.MaxTokens, System: req.System,
		Temperature: req.Temperature, Stream: true, Messages: anthropicMessages(req.Messages),
	}
	for _, t := range req.Tools {
		body.Tools = append(body.Tools, anthropicTool{Name: t.Name, Description: t.Description, InputSchema: t.Schema})
	}
	if len(body.Tools) > 0 && req.NoMoreToolCalls {
		body.ToolChoice = &anthropicChoice{Type: "none"}
	}

	var result StreamResult
	// Tool calls by content block index: their arguments arrive as pieces.
	calls := map[int]*ToolCall{}
	args := map[int]*strings.Builder{}
	var order []int
	err := p.postStream(ctx, p.baseURL+"/v1/messages", p.headers(), body, func(ev sseEvent) error {
		var e anthropicEvent
		if err := json.Unmarshal([]byte(ev.Data), &e); err != nil {
			return &Error{Kind: ErrBadResponse, Message: "unreadable stream event"}
		}
		switch e.Type {
		case "message_start":
			result.InputTokens = e.Message.Usage.InputTokens
			result.OutputTokens = e.Message.Usage.OutputTokens
		case "content_block_start":
			if e.ContentBlock.Type == "tool_use" {
				calls[e.Index] = &ToolCall{ID: e.ContentBlock.ID, Name: e.ContentBlock.Name}
				args[e.Index] = &strings.Builder{}
				order = append(order, e.Index)
			}
		case "content_block_delta":
			switch {
			case e.Delta.Type == "text_delta" && e.Delta.Text != "":
				return onDelta(e.Delta.Text)
			case e.Delta.Type == "input_json_delta" && args[e.Index] != nil:
				args[e.Index].WriteString(e.Delta.PartialJSON)
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
	for _, i := range order {
		c := calls[i]
		c.Args = argsOrEmpty(json.RawMessage(args[i].String()))
		result.ToolCalls = append(result.ToolCalls, *c)
	}
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
