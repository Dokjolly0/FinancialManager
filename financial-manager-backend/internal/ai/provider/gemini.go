package provider

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strconv"
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
	Text             string                  `json:"text,omitempty"`
	FunctionCall     *geminiFunctionCall     `json:"functionCall,omitempty"`
	FunctionResponse *geminiFunctionResponse `json:"functionResponse,omitempty"`
	// ThoughtSignature must travel back with the function call it came
	// with (thinking models refuse the next turn otherwise).
	ThoughtSignature string `json:"thoughtSignature,omitempty"`
}

type geminiFunctionCall struct {
	ID   string          `json:"id,omitempty"`
	Name string          `json:"name"`
	Args json.RawMessage `json:"args,omitempty"`
}

type geminiFunctionResponse struct {
	ID       string         `json:"id,omitempty"`
	Name     string         `json:"name"`
	Response map[string]any `json:"response"`
}

type geminiFunctionDeclaration struct {
	Name        string          `json:"name"`
	Description string          `json:"description"`
	Parameters  json.RawMessage `json:"parameters"`
}

type geminiTool struct {
	FunctionDeclarations []geminiFunctionDeclaration `json:"functionDeclarations"`
}

type geminiContent struct {
	Role  string       `json:"role,omitempty"`
	Parts []geminiPart `json:"parts"`
}

type geminiGenerationConfig struct {
	MaxOutputTokens int                   `json:"maxOutputTokens,omitempty"`
	Temperature     *float64              `json:"temperature,omitempty"`
	ThinkingConfig  *geminiThinkingConfig `json:"thinkingConfig,omitempty"`
}

// geminiThinkingConfig limits reasoning: Gemini 2.5 takes a token budget,
// Gemini 3 and later a level (sending both is refused).
type geminiThinkingConfig struct {
	ThinkingBudget *int   `json:"thinkingBudget,omitempty"`
	ThinkingLevel  string `json:"thinkingLevel,omitempty"`
}

var geminiMajorVersion = regexp.MustCompile(`^gemini-(\d+)`)

// minimalGeminiThinking is the least reasoning the model accepts, nil for
// models without thinking or whose family is unknown.
func minimalGeminiThinking(model string) *geminiThinkingConfig {
	id := strings.ToLower(model)
	if strings.HasPrefix(id, "gemini-2.5") {
		// Pro cannot turn thinking off: 128 is its minimum budget.
		budget := 0
		if strings.Contains(id, "pro") {
			budget = 128
		}
		return &geminiThinkingConfig{ThinkingBudget: &budget}
	}
	if m := geminiMajorVersion.FindStringSubmatch(id); m != nil {
		if major, err := strconv.Atoi(m[1]); err == nil && major >= 3 {
			// "low" is accepted by every Gemini 3 model ("minimal" only by Flash).
			return &geminiThinkingConfig{ThinkingLevel: "low"}
		}
	}
	return nil
}

type geminiRequest struct {
	SystemInstruction *geminiContent         `json:"systemInstruction,omitempty"`
	Contents          []geminiContent        `json:"contents"`
	GenerationConfig  geminiGenerationConfig `json:"generationConfig"`
	Tools             []geminiTool           `json:"tools,omitempty"`
	ToolConfig        *geminiToolConfig      `json:"toolConfig,omitempty"`
}

type geminiToolConfig struct {
	FunctionCallingConfig struct {
		Mode string `json:"mode"`
	} `json:"functionCallingConfig"`
}

type geminiChunk struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text             string              `json:"text"`
				Thought          bool                `json:"thought"`
				FunctionCall     *geminiFunctionCall `json:"functionCall"`
				ThoughtSignature string              `json:"thoughtSignature"`
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
	body.Contents = geminiContents(req.Messages)
	if len(req.Tools) > 0 {
		decls := make([]geminiFunctionDeclaration, 0, len(req.Tools))
		for _, t := range req.Tools {
			decls = append(decls, geminiFunctionDeclaration{Name: t.Name, Description: t.Description, Parameters: t.Schema})
		}
		body.Tools = []geminiTool{{FunctionDeclarations: decls}}
		if req.NoMoreToolCalls {
			body.ToolConfig = &geminiToolConfig{}
			body.ToolConfig.FunctionCallingConfig.Mode = "NONE"
		}
	}

	model := strings.TrimPrefix(req.Model, "models/")
	endpoint := p.baseURL + "/v1beta/models/" + url.PathEscape(model) + ":streamGenerateContent?alt=sse"

	if req.MinimalReasoning {
		if tc := minimalGeminiThinking(model); tc != nil {
			body.GenerationConfig.ThinkingConfig = tc
			// The budget counts towards maxOutputTokens: leave room for text.
			if tc.ThinkingBudget != nil && body.GenerationConfig.MaxOutputTokens > 0 {
				body.GenerationConfig.MaxOutputTokens += *tc.ThinkingBudget
			}
			result, err := p.stream(ctx, endpoint, body, onDelta)
			var pe *Error
			if !errors.As(err, &pe) || pe.Status != http.StatusBadRequest || pe.Kind != ErrBadResponse {
				return result, err
			}
			// A model that refuses the thinking setting (a family guessed
			// wrong): ask again with the provider defaults.
			body.GenerationConfig.ThinkingConfig = nil
			body.GenerationConfig.MaxOutputTokens = req.MaxTokens
		}
	}
	return p.stream(ctx, endpoint, body, onDelta)
}

func (p *geminiProvider) stream(ctx context.Context, endpoint string, body geminiRequest, onDelta func(string) error) (StreamResult, error) {
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
				if fc := part.FunctionCall; fc != nil {
					// Calls arrive whole; older models give no id.
					id := fc.ID
					if id == "" {
						id = fmt.Sprintf("call_%d", len(result.ToolCalls)+1)
					}
					result.ToolCalls = append(result.ToolCalls, ToolCall{
						ID: id, Name: fc.Name, Args: argsOrEmpty(fc.Args), Signature: part.ThoughtSignature,
					})
					continue
				}
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

// geminiContents turns the conversation into contents: the model's calls
// as functionCall parts after its text, results as functionResponse parts
// of a user turn.
func geminiContents(messages []Message) []geminiContent {
	out := make([]geminiContent, 0, len(messages))
	for _, m := range messages {
		role := "user"
		if m.Role == RoleAssistant {
			role = "model"
		}
		var parts []geminiPart
		if m.Content != "" || (len(m.ToolCalls) == 0 && len(m.ToolResults) == 0) {
			parts = append(parts, geminiPart{Text: m.Content})
		}
		for _, c := range m.ToolCalls {
			parts = append(parts, geminiPart{
				FunctionCall:     &geminiFunctionCall{Name: c.Name, Args: argsOrEmpty(c.Args)},
				ThoughtSignature: c.Signature,
			})
		}
		for _, r := range m.ToolResults {
			parts = append(parts, geminiPart{FunctionResponse: &geminiFunctionResponse{
				Name: r.Name, Response: map[string]any{"content": r.Content},
			}})
		}
		out = append(out, geminiContent{Role: role, Parts: parts})
	}
	return out
}

// nonTextGeminiMarkers excludes the Gemini models that declare
// generateContent but answer only with audio or images, or need a
// special setup: they reject a text chat with a 400.
var nonTextGeminiMarkers = []string{
	"tts", "image", "audio", "live", "embedding", "aqa", "robotics", "computer-use",
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
		id := strings.TrimPrefix(m.Name, "models/")
		if !slices.Contains(m.SupportedGenerationMethods, "generateContent") ||
			containsAny(strings.ToLower(id), nonTextGeminiMarkers...) {
			continue
		}
		models = append(models, ModelInfo{ID: id, DisplayName: m.DisplayName})
	}
	return models, nil
}
