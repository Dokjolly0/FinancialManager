package provider

import (
	"context"
	"encoding/json"
	"net/url"
	"slices"
	"strings"
)

// geminiProvider implements the Gemini API with streaming
// (POST /v1beta/models/{model}:streamGenerateContent?alt=sse).
type geminiProvider struct {
	baseHTTP
}

func (p *geminiProvider) headers() map[string]string {
	return map[string]string{"x-goog-api-key": p.apiKey}
}

type geminiPart struct {
	Text string `json:"text"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type geminiGenerationConfig struct {
	MaxOutputTokens int      `json:"maxOutputTokens,omitempty"`
	Temperature     *float64 `json:"temperature,omitempty"`
}

type geminiRequest struct {
	SystemInstruction *geminiContent         `json:"systemInstruction,omitempty"`
	Contents          []geminiContent        `json:"contents"`
	GenerationConfig  geminiGenerationConfig `json:"generationConfig"`
}

type geminiChunk struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text    string `json:"text"`
				Thought bool   `json:"thought"`
			} `json:"parts"`
		} `json:"content"`
		FinishReason string `json:"finishReason"`
	} `json:"candidates"`
	PromptFeedback *struct {
		BlockReason string `json:"blockReason"`
	} `json:"promptFeedback"`
	UsageMetadata *struct {
		PromptTokenCount     int `json:"promptTokenCount"`
		CandidatesTokenCount int `json:"candidatesTokenCount"`
		ThoughtsTokenCount   int `json:"thoughtsTokenCount"`
	} `json:"usageMetadata"`
	Error *struct {
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error"`
}

// geminiBlockedReasons are finish reasons that mean the answer was
// withheld rather than finished.
var geminiBlockedReasons = []string{"SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION"}

func (p *geminiProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	body := geminiRequest{
		GenerationConfig: geminiGenerationConfig{MaxOutputTokens: req.MaxTokens, Temperature: req.Temperature},
	}
	if req.System != "" {
		body.SystemInstruction = &geminiContent{Parts: []geminiPart{{Text: req.System}}}
	}
	for _, m := range req.Messages {
		role := "user"
		if m.Role == RoleAssistant {
			role = "model"
		}
		body.Contents = append(body.Contents, geminiContent{Role: role, Parts: []geminiPart{{Text: m.Content}}})
	}

	model := strings.TrimPrefix(req.Model, "models/")
	endpoint := p.baseURL + "/v1beta/models/" + url.PathEscape(model) + ":streamGenerateContent?alt=sse"

	var result StreamResult
	err := p.postStream(ctx, endpoint, p.headers(), body, func(ev sseEvent) error {
		var chunk geminiChunk
		if err := json.Unmarshal([]byte(ev.Data), &chunk); err != nil {
			return &Error{Kind: ErrBadResponse, Message: "unreadable stream event"}
		}
		if chunk.Error != nil {
			return classifyHTTP(0, []byte(`{"error":{"message":`+quoteJSON(chunk.Error.Message+" "+chunk.Error.Status)+`}}`))
		}
		if chunk.PromptFeedback != nil && chunk.PromptFeedback.BlockReason != "" {
			return &Error{Kind: ErrContentBlocked, Message: "prompt blocked: " + chunk.PromptFeedback.BlockReason}
		}
		if u := chunk.UsageMetadata; u != nil {
			result.InputTokens = u.PromptTokenCount
			result.OutputTokens = u.CandidatesTokenCount + u.ThoughtsTokenCount
		}
		for _, c := range chunk.Candidates {
			for _, part := range c.Content.Parts {
				if part.Thought || part.Text == "" {
					continue
				}
				if err := onDelta(part.Text); err != nil {
					return err
				}
			}
			switch {
			case c.FinishReason == "MAX_TOKENS":
				result.Truncated = true
			case slices.Contains(geminiBlockedReasons, c.FinishReason):
				return &Error{Kind: ErrContentBlocked, Message: "response blocked: " + c.FinishReason}
			}
		}
		return nil
	})
	return result, err
}

func (p *geminiProvider) ListModels(ctx context.Context) ([]ModelInfo, error) {
	var resp struct {
		Models []struct {
			Name                       string   `json:"name"`
			DisplayName                string   `json:"displayName"`
			SupportedGenerationMethods []string `json:"supportedGenerationMethods"`
		} `json:"models"`
	}
	if err := p.getJSON(ctx, p.baseURL+"/v1beta/models?pageSize=1000", p.headers(), &resp); err != nil {
		return nil, err
	}
	models := make([]ModelInfo, 0, len(resp.Models))
	for _, m := range resp.Models {
		if !slices.Contains(m.SupportedGenerationMethods, "generateContent") {
			continue
		}
		models = append(models, ModelInfo{ID: strings.TrimPrefix(m.Name, "models/"), DisplayName: m.DisplayName})
	}
	return models, nil
}
