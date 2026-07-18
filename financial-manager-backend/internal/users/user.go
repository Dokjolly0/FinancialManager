// Package users implements the applicational user profile (plan.md
// section 4.1: "identità applicativa, indipendente dal metodo di
// autenticazione") — not credentials or sessions, which live in
// internal/auth.
package users

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	AvatarModeGenerated = "generated"
	AvatarModeCustom    = "custom"
)

const (
	StatusActive          = "active"
	StatusPendingDeletion = "pending_deletion"
	StatusDeleted         = "deleted"
)

type User struct {
	ID                    uuid.UUID
	FirstName             string
	LastName              string
	Username              string
	UsernameNormalized    string
	Email                 string
	EmailNormalized       string
	EmailVerifiedAt       *time.Time
	AvatarMode            string
	AvatarMediaID         *uuid.UUID
	AvatarBackgroundColor string
	AvatarTextColor       string
	Locale                string
	Timezone              string
	Theme                 string
	Status                string
	CreatedAt             time.Time
	UpdatedAt             time.Time
	DeletedAt             *time.Time
	Version               int64
}

func (u User) EmailVerified() bool { return u.EmailVerifiedAt != nil }

// NormalizeUsername mirrors plan.md section 4.4's title normalization
// rule applied to usernames: trim, compact internal spaces, lowercase for
// uniqueness comparison.
func NormalizeUsername(username string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(username)), " "))
}

// NormalizeEmail lowercases and trims the email for uniqueness comparison.
// The displayed email retains the user's original casing.
func NormalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}
