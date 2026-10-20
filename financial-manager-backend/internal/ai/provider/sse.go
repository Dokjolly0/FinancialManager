package provider

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	maxSSELineBytes      = 1 << 20
	maxJSONResponseBytes = 1 << 20
	maxErrorBodyBytes    = 64 << 10
)

// baseHTTP is shared by the adapters.
type baseHTTP struct {
	client      *http.Client
	baseURL     string
	apiKey      string
	idleTimeout time.Duration
}

// getJSON performs a GET and decodes a JSON body of at most 1 MiB.
func (b baseHTTP) getJSON(ctx context.Context, url string, headers map[string]string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	req.Header.Set("Accept", "application/json")
	resp, err := b.client.Do(req)
	if err != nil {
		return classifyTransport(ctx, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, maxErrorBodyBytes))
		return classifyHTTP(resp.StatusCode, body)
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, maxJSONResponseBytes)).Decode(out); err != nil {
		return &Error{Kind: ErrBadResponse, Status: resp.StatusCode, Message: "unreadable model list"}
	}
	return nil
}

// postStream sends a JSON body and calls onEvent for every server-sent
// event of a 2xx response. An idle watchdog cancels the request when the
// provider sends nothing for idleTimeout.
func (b baseHTTP) postStream(ctx context.Context, url string, headers map[string]string, body any, onEvent func(sseEvent) error) error {
	payload, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("encode request: %w", err)
	}

	streamCtx, cancel := context.WithCancelCause(ctx)
	defer cancel(nil)

	req, err := http.NewRequestWithContext(streamCtx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "text/event-stream")

	resp, err := b.client.Do(req)
	if err != nil {
		return classifyTransport(streamCtx, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		errBody, _ := io.ReadAll(io.LimitReader(resp.Body, maxErrorBodyBytes))
		return classifyHTTP(resp.StatusCode, errBody)
	}

	reader := io.Reader(resp.Body)
	if b.idleTimeout > 0 {
		w := newIdleWatchdog(b.idleTimeout, func() { cancel(errIdle) })
		defer w.stop()
		reader = w.wrap(resp.Body)
	}

	if err := readSSE(reader, onEvent); err != nil {
		var pe *Error
		switch {
		case errors.Is(err, errStreamDone):
			return nil
		case errors.As(err, &pe):
			return pe
		case streamCtx.Err() != nil:
			return classifyTransport(streamCtx, err)
		}
		// An error from the caller's onDelta, returned as is.
		return err
	}
	if streamCtx.Err() != nil {
		return classifyTransport(streamCtx, streamCtx.Err())
	}
	return nil
}

// sseEvent is one server-sent event; Data joins multi-line data fields.
type sseEvent struct {
	Event string
	Data  string
}

// readSSE parses a text/event-stream body. Comment lines (": ping") are
// skipped; an event is dispatched on each blank line and at EOF.
func readSSE(r io.Reader, onEvent func(sseEvent) error) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64<<10), maxSSELineBytes)

	var event string
	var data []string
	dispatch := func() error {
		if len(data) == 0 {
			event = ""
			return nil
		}
		ev := sseEvent{Event: event, Data: strings.Join(data, "\n")}
		event, data = "", nil
		return onEvent(ev)
	}

	for scanner.Scan() {
		line := strings.TrimSuffix(scanner.Text(), "\r")
		switch {
		case line == "":
			if err := dispatch(); err != nil {
				return err
			}
		case strings.HasPrefix(line, ":"):
		default:
			field, value, _ := strings.Cut(line, ":")
			value = strings.TrimPrefix(value, " ")
			switch field {
			case "event":
				event = value
			case "data":
				data = append(data, value)
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return dispatch()
}

// errStreamDone stops readSSE without an error (OpenAI's "[DONE]").
var errStreamDone = errors.New("stream done")

// idleWatchdog fires when no bytes were read for d.
type idleWatchdog struct {
	mu    sync.Mutex
	timer *time.Timer
	d     time.Duration
}

func newIdleWatchdog(d time.Duration, fire func()) *idleWatchdog {
	return &idleWatchdog{timer: time.AfterFunc(d, fire), d: d}
}

func (w *idleWatchdog) wrap(r io.Reader) io.Reader {
	return readerFunc(func(p []byte) (int, error) {
		n, err := r.Read(p)
		if n > 0 {
			w.mu.Lock()
			w.timer.Reset(w.d)
			w.mu.Unlock()
		}
		return n, err
	})
}

func (w *idleWatchdog) stop() {
	w.mu.Lock()
	w.timer.Stop()
	w.mu.Unlock()
}

type readerFunc func([]byte) (int, error)

func (f readerFunc) Read(p []byte) (int, error) { return f(p) }
