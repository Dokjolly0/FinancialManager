package provider

import (
	"context"
	"sync"
	"time"
)

// ScriptedProvider replays canned deltas; used by the ai package tests in
// place of a real provider.
type ScriptedProvider struct {
	Deltas        []string
	Result        StreamResult
	Err           error // returned after the deltas
	DelayPerDelta time.Duration
	Models        []ModelInfo
	ModelsErr     error

	mu       sync.Mutex
	Requests []ChatRequest
}

func (s *ScriptedProvider) Stream(ctx context.Context, req ChatRequest, onDelta func(string) error) (StreamResult, error) {
	s.mu.Lock()
	s.Requests = append(s.Requests, req)
	s.mu.Unlock()

	for _, d := range s.Deltas {
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
	if s.Err != nil {
		return StreamResult{}, s.Err
	}
	return s.Result, nil
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
