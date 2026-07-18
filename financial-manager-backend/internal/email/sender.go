// Package email abstracts outbound email (verification, password reset,
// security notices — plan.md section 2.1C, 15.5, 20.2) behind a small
// interface so a real SMTP/API provider can be plugged in later. No email
// provider has been chosen yet (plan.md section 28.10 is still open), so
// the only implementation today logs the message instead of sending it —
// safe for local/test, and loud enough in staging that nobody mistakes it
// for real delivery.
package email

import (
	"context"
	"log/slog"
)

type Message struct {
	To      string
	Subject string
	Body    string
}

type Sender interface {
	Send(ctx context.Context, msg Message) error
}

// DevLogSender logs the message instead of delivering it. It intentionally
// does not log the full body by default beyond a short preview, consistent
// with not logging user content unnecessarily (plan.md section 19.7).
type DevLogSender struct {
	Logger *slog.Logger
}

func (s DevLogSender) Send(ctx context.Context, msg Message) error {
	s.Logger.InfoContext(ctx, "email_not_sent_no_provider_configured",
		slog.String("to", msg.To),
		slog.String("subject", msg.Subject),
	)
	return nil
}
