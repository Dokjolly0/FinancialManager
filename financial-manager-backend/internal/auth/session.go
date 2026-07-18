// Package auth implements local credentials and sessions (plan.md section
// 4.1, 15, 11.3-11.5). Google identity linking is a separate concern added
// in Fase 3 of the roadmap; this package only knows about password-based
// login and refresh-token sessions.
package auth

import (
	"time"

	"github.com/google/uuid"
)

type Session struct {
	ID                  uuid.UUID
	UserID              uuid.UUID
	RefreshTokenHash    []byte
	DeviceName          *string
	Platform            *string
	CreatedAt           time.Time
	LastUsedAt          time.Time
	ExpiresAt           time.Time
	RevokedAt           *time.Time
	ReplacedBySessionID *uuid.UUID
}

func (s Session) Active(now time.Time) bool {
	return s.RevokedAt == nil && now.Before(s.ExpiresAt)
}
