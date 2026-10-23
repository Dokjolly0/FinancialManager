package email

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"
)

type recordingSender struct {
	mu    sync.Mutex
	sent  []Message
	err   error
	delay time.Duration
}

func (r *recordingSender) Send(ctx context.Context, msg Message) error {
	select {
	case <-time.After(r.delay):
	case <-ctx.Done():
		return ctx.Err()
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.sent = append(r.sent, msg)
	return r.err
}

func TestAsyncSender_ReturnsBeforeDeliveryAndWaitFlushes(t *testing.T) {
	next := &recordingSender{delay: 100 * time.Millisecond}
	a := NewAsync(next, slog.New(slog.NewTextHandler(&bytes.Buffer{}, nil)), time.Second)

	start := time.Now()
	if err := a.Send(context.Background(), Message{To: "a@example.com", Subject: "s"}); err != nil {
		t.Fatalf("Send: %v", err)
	}
	if time.Since(start) > 50*time.Millisecond {
		t.Error("Send waited for the delivery")
	}

	if err := a.Wait(context.Background()); err != nil {
		t.Fatalf("Wait: %v", err)
	}
	if len(next.sent) != 1 {
		t.Fatalf("delivered %d messages, want 1", len(next.sent))
	}
}

func TestAsyncSender_DeliveryOutlivesRequestContext(t *testing.T) {
	next := &recordingSender{delay: 50 * time.Millisecond}
	a := NewAsync(next, slog.New(slog.NewTextHandler(&bytes.Buffer{}, nil)), time.Second)

	ctx, cancel := context.WithCancel(context.Background())
	_ = a.Send(ctx, Message{To: "a@example.com", Subject: "s"})
	cancel() // the response has been written

	_ = a.Wait(context.Background())
	if len(next.sent) != 1 {
		t.Fatal("the message was dropped when the request context ended")
	}
}

func TestAsyncSender_LogsFailuresWithoutBody(t *testing.T) {
	var logs bytes.Buffer
	next := &recordingSender{err: errors.New("535 authentication failed")}
	a := NewAsync(next, slog.New(slog.NewTextHandler(&logs, nil)), time.Second)

	_ = a.Send(context.Background(), Message{To: "a@example.com", Subject: "Reimposta", Body: "secret-link"})
	_ = a.Wait(context.Background())

	out := logs.String()
	if !strings.Contains(out, "email_send_failed") || !strings.Contains(out, "535 authentication failed") {
		t.Errorf("failure not logged: %s", out)
	}
	if strings.Contains(out, "secret-link") {
		t.Error("the body (with its single-use link) was logged")
	}
}

func TestAsyncSender_WaitHonorsContext(t *testing.T) {
	next := &recordingSender{delay: time.Second}
	a := NewAsync(next, slog.New(slog.NewTextHandler(&bytes.Buffer{}, nil)), 5*time.Second)
	_ = a.Send(context.Background(), Message{To: "a@example.com"})

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	if err := a.Wait(ctx); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("Wait = %v, want deadline exceeded", err)
	}
}
