package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// --- Per-user stream lock ---------------------------------------------------

// StreamLocker allows one analysis stream per user at a time, across API
// instances (plan.md section 32.8).
type StreamLocker interface {
	// TryLock takes key for at most ttl. ok is false when it is held.
	TryLock(ctx context.Context, key string, ttl time.Duration) (unlock func(), ok bool, err error)
}

// RedisLocker is the production StreamLocker.
type RedisLocker struct {
	Client *redis.Client
}

// unlockScript deletes the key only if it still holds our token, so a
// lock that expired and was taken by another stream is left alone.
var unlockScript = redis.NewScript(`
if redis.call("GET", KEYS[1]) == ARGV[1] then
	return redis.call("DEL", KEYS[1])
end
return 0`)

func (l RedisLocker) TryLock(ctx context.Context, key string, ttl time.Duration) (func(), bool, error) {
	token := uuid.NewString()
	ok, err := l.Client.SetNX(ctx, key, token, ttl).Result()
	if err != nil || !ok {
		return nil, false, err
	}
	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = unlockScript.Run(ctx, l.Client, []string{key}, token).Err()
	}, true, nil
}

// memoryLocker is the single-process fallback, used when no Redis locker
// is configured (tests).
type memoryLocker struct {
	mu   sync.Mutex
	held map[string]time.Time
}

func newMemoryLocker() *memoryLocker { return &memoryLocker{held: map[string]time.Time{}} }

func (l *memoryLocker) TryLock(_ context.Context, key string, ttl time.Duration) (func(), bool, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if until, ok := l.held[key]; ok && time.Now().Before(until) {
		return nil, false, nil
	}
	l.held[key] = time.Now().Add(ttl)
	return func() {
		l.mu.Lock()
		delete(l.held, key)
		l.mu.Unlock()
	}, true, nil
}

// --- Server-sent events -------------------------------------------------------

// EventSink receives a stream's events. Delta text may be batched.
type EventSink interface {
	Delta(text string) error
	Event(name string, data any) error
}

const (
	deltaFlushInterval = 50 * time.Millisecond
	deltaFlushBytes    = 256
	pingInterval       = 15 * time.Second
)

// SSEWriter writes text/event-stream responses. Deltas are coalesced
// (about every 50 ms or 256 bytes) so a fast model doesn't cost one write
// and one flush per token, and a ": ping" comment every 15 s keeps proxies
// from closing an idle connection while the model thinks.
type SSEWriter struct {
	mu      sync.Mutex
	w       http.ResponseWriter
	rc      *http.ResponseController
	pending strings.Builder
	err     error
	stop    chan struct{}
	done    chan struct{}
}

// NewSSEWriter sends the SSE headers and starts the flush loop. Call Close
// when the stream ends.
func NewSSEWriter(w http.ResponseWriter) *SSEWriter {
	h := w.Header()
	h.Set("Content-Type", "text/event-stream")
	h.Set("Cache-Control", "no-cache")
	h.Set("Connection", "keep-alive")
	// Disables response buffering in nginx; other proxies are covered in
	// docs/build-deploy.md.
	h.Set("X-Accel-Buffering", "no")
	w.WriteHeader(http.StatusOK)

	s := &SSEWriter{w: w, rc: http.NewResponseController(w), stop: make(chan struct{}), done: make(chan struct{})}
	_ = s.rc.Flush()
	go s.loop()
	return s
}

func (s *SSEWriter) loop() {
	defer close(s.done)
	flush := time.NewTicker(deltaFlushInterval)
	ping := time.NewTicker(pingInterval)
	defer flush.Stop()
	defer ping.Stop()
	for {
		select {
		case <-s.stop:
			return
		case <-flush.C:
			s.mu.Lock()
			s.flushPendingLocked()
			s.mu.Unlock()
		case <-ping.C:
			s.mu.Lock()
			s.writeLocked(": ping\n\n")
			s.mu.Unlock()
		}
	}
}

func (s *SSEWriter) writeLocked(raw string) {
	if s.err != nil {
		return
	}
	if _, err := fmt.Fprint(s.w, raw); err != nil {
		s.err = err
		return
	}
	s.err = s.rc.Flush()
}

func (s *SSEWriter) eventLocked(name string, data any) {
	payload, err := json.Marshal(data)
	if err != nil {
		s.err = err
		return
	}
	s.writeLocked("event: " + name + "\ndata: " + string(payload) + "\n\n")
}

func (s *SSEWriter) flushPendingLocked() {
	if s.pending.Len() == 0 {
		return
	}
	text := s.pending.String()
	s.pending.Reset()
	s.eventLocked("delta", map[string]string{"text": text})
}

// Delta queues text for the next delta event.
func (s *SSEWriter) Delta(text string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.pending.WriteString(text)
	if s.pending.Len() >= deltaFlushBytes {
		s.flushPendingLocked()
	}
	return s.err
}

// Event sends any queued text, then the event.
func (s *SSEWriter) Event(name string, data any) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.flushPendingLocked()
	s.eventLocked(name, data)
	return s.err
}

// Close stops the flush loop and sends any queued text.
func (s *SSEWriter) Close() {
	close(s.stop)
	<-s.done
	s.mu.Lock()
	s.flushPendingLocked()
	s.mu.Unlock()
}
