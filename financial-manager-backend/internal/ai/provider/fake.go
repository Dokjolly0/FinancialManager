package provider

import (
	"context"
	"sync"
	"time"
)

// ScriptedTurn is one scripted model response: text, then tool calls.
type ScriptedTurn struct {
	Deltas    []string
	ToolCalls []ToolCall
	Result    StreamResult
	Err       error
}

// ScriptedProvider replays canned deltas; used by the ai package tests in
// place of a real provider. With Turns set, each Stream call plays the
// next turn (the last one repeats); otherwise Deltas, Result and Err.
type ScriptedProvider struct {
	Deltas        []string
	Result        StreamResult
	Err           error // returned after the deltas
	DelayPerDelta time.Duration
	Models        []ModelInfo
	ModelsErr     error

	Turns []ScriptedTurn
	// RejectTools makes a request with tools fail with
	// ErrToolsUnsupported, as an OpenAI-compatible server without function
	// calling does.
	RejectTools bool

	mu       sync.Mutex
	Requests []ChatRequest
	turn     int
}

func (s *ScriptedProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	s.mu.Lock()
	s.Requests = append(s.Requests, req)
	turn := ScriptedTurn{Deltas: s.Deltas, Result: s.Result, Err: s.Err}
	if len(s.Turns) > 0 {
		turn = s.Turns[min(s.turn, len(s.Turns)-1)]
		s.turn++
	}
	s.mu.Unlock()

	if s.RejectTools && len(req.Tools) > 0 {
		return StreamResult{}, &Error{Kind: ErrToolsUnsupported, Status: 400, Message: "tools are not supported"}
	}
	for _, d := range turn.Deltas {
		if s.DelayPerDelta > 0 {
			select {
			case <-time.After(s.DelayPerDelta):
			case <-ctx.Done():
				return StreamResult{}, ctx.Err()
			}
		}
		if err := ctx.Err(); err != nil {
			return StreamResult{}, err
		}
		if err := onDelta(d); err != nil {
			return StreamResult{}, err
		}
	}
	if turn.Err != nil {
		return StreamResult{}, turn.Err
	}
	result := turn.Result
	result.ToolCalls = turn.ToolCalls
	return result, nil
}

func (s *ScriptedProvider) ListModels(context.Context) ([]ModelInfo, error) {
	return s.Models, s.ModelsErr
}

// LastRequest returns the most recent request, for assertions.
func (s *ScriptedProvider) LastRequest() ChatRequest {
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.Requests) == 0 {
		return ChatRequest{}
	}
	return s.Requests[len(s.Requests)-1]
}

// StaticFactory always returns the same provider and records the configs
// it was asked for.
type StaticFactory struct {
	Provider Provider
	Err      error

	mu      sync.Mutex
	Configs []Config
}

func (f *StaticFactory) New(cfg Config) (Provider, error) {
	f.mu.Lock()
	f.Configs = append(f.Configs, cfg)
	f.mu.Unlock()
	if f.Err != nil {
		return nil, f.Err
	}
	return f.Provider, nil
}
