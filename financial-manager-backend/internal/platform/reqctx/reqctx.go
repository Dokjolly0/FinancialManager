// Package reqctx carries the authenticated principal (user ID, session ID)
// through request context. It exists as its own tiny, dependency-free
// package so both the auth middleware (which sets it) and every other
// module's handlers (which read it) can depend on it without a cycle
// through internal/auth.
package reqctx

import (
	"context"

	"github.com/google/uuid"
)

type contextKey int

const (
	userIDKey contextKey = iota
	sessionIDKey
)

func WithUser(ctx context.Context, userID, sessionID uuid.UUID) context.Context {
	ctx = context.WithValue(ctx, userIDKey, userID)
	ctx = context.WithValue(ctx, sessionIDKey, sessionID)
	return ctx
}

// UserID returns the authenticated user's ID. ok is false if the request
// was not authenticated (the route should not have been reachable in that
// case — handlers still check it defensively).
func UserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

func SessionID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(sessionIDKey).(uuid.UUID)
	return id, ok
}
