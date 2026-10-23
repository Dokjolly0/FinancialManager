// Package email sends outbound email (verification, password reset —
// plan.md section 2.1C, 15.5, 20.2). SMTPSender delivers through any SMTP
// server (a Gmail account with an app password, a transactional provider,
// Mailpit in development); AsyncSender sends in the background so a slow
// mail server neither delays the request nor reveals, by its timing,
// whether an account exists. Without SMTP configuration the API falls back
// to DevLogSender, which only logs that a message was not sent.
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
// does not log the body, which carries single-use links, consistent with
// not logging user content unnecessarily (plan.md section 19.7).
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
