package email

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"financial-manager-backend/internal/platform/metrics"
)

// AsyncSender hands each message to Next in its own goroutine and returns
// at once. Requests don't wait for the mail server, and "forgot password"
// takes the same time whether or not the account exists (plan.md section
// 15.5). Delivery failures are logged and counted, never returned: the
// caller has already answered the client.
type AsyncSender struct {
	next    Sender
	logger  *slog.Logger
	timeout time.Duration
	wg      sync.WaitGroup
}

// NewAsync wraps next; timeout bounds each delivery attempt.
func NewAsync(next Sender, logger *slog.Logger, timeout time.Duration) *AsyncSender {
	return &AsyncSender{next: next, logger: logger, timeout: timeout}
}

func (a *AsyncSender) Send(ctx context.Context, msg Message) error {
	a.wg.Add(1)
	go func() {
		defer a.wg.Done()
		// The request's context ends as soon as the response is written;
		// keep its values (request ID for the logs), drop its cancellation.
		sendCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), a.timeout)
		defer cancel()
		start := time.Now()
		if err := a.next.Send(sendCtx, msg); err != nil {
			metrics.EmailsTotal.WithLabelValues("failed").Inc()
			a.logger.ErrorContext(sendCtx, "email_send_failed",
				slog.String("subject", msg.Subject),
				slog.String("error", err.Error()),
			)
			return
		}
		metrics.EmailsTotal.WithLabelValues("sent").Inc()
		a.logger.InfoContext(sendCtx, "email_sent",
			slog.String("subject", msg.Subject),
			slog.Duration("duration", time.Since(start)),
		)
	}()
	return nil
}

// Wait blocks until every message handed to Send has been attempted, or
// ctx ends. Called on shutdown so a deploy doesn't drop emails in flight.
func (a *AsyncSender) Wait(ctx context.Context) error {
	done := make(chan struct{})
	go func() {
		a.wg.Wait()
		close(done)
	}()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
