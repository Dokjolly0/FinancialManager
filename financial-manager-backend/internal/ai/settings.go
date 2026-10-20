// Package ai implements the AI analysis (plan.md section 32): per-user
// provider settings with encrypted API keys, personal context, prompt
// preview, streamed analyses with follow-up questions, and their history.
package ai

import (
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/provider"
)

// ConsentVersion is the version of the disclosure the app shows before the
// first analysis. Bump it whenever that text changes in a way users must
// see again: preview and run then answer AI_CONSENT_REQUIRED until the
// user accepts the new version.
const ConsentVersion = 1

// Limits shared by validation and the database CHECKs (migrations 0031 and
// 0032).
const (
	MinMaxOutputTokens     = 256
	MaxMaxOutputTokens     = 32000
	DefaultMaxOutputTokens = 4096
	MaxModelLength         = 200
	MaxAPIKeyLength        = 512
	MaxContextTextLength   = 2000
	MaxHouseholdSize       = 20
)

// Credential is one stored provider account.
type Credential struct {
	ID              uuid.UUID
	UserID          uuid.UUID
	Provider        provider.Kind
	BaseURL         string // "" for native providers
	APIKeyEncrypted []byte // nil when no key is stored
	APIKeyHint      *string
	Model           *string
	LastTestedAt    *time.Time
	LastTestOK      *bool
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

func (c Credential) HasKey() bool { return c.APIKeyEncrypted != nil }

// Settings is the user's AI configuration. A user without a row behaves as
// the zero Settings with Version 0 and the defaults below.
type Settings struct {
	UserID                     uuid.UUID
	ActiveCredentialID         *uuid.UUID
	ConsentVersion             *int
	ConsentAcceptedAt          *time.Time
	MaxOutputTokens            int
	InputPricePerMTok          *float64
	OutputPricePerMTok         *float64
	DefaultIncludeTransactions bool
	DefaultAnonymizeTitles     bool
	Version                    int64
}

func defaultSettings(userID uuid.UUID) Settings {
	return Settings{UserID: userID, MaxOutputTokens: DefaultMaxOutputTokens}
}

// HasCurrentConsent reports whether the user accepted the current
// disclosure.
func (s Settings) HasCurrentConsent() bool {
	return s.ConsentVersion != nil && *s.ConsentVersion >= ConsentVersion
}

// Income types and response styles accepted in UserContext.
var (
	ValidIncomeTypes = map[string]bool{
		"EMPLOYEE": true, "SELF_EMPLOYED": true, "STUDENT": true, "RETIRED": true,
		"UNEMPLOYED": true, "MIXED": true, "OTHER": true,
	}
	ValidResponseStyles = map[string]bool{"CONCISE": true, "DETAILED": true}
)

// UserContext is what the user wants the model to know about them.
type UserContext struct {
	UserID        uuid.UUID
	HouseholdSize *int
	IncomeType    *string
	AboutMe       *string
	Goals         *string
	IgnoreNotes   *string
	ResponseStyle *string
	Version       int64
	UpdatedAt     *time.Time
}

// IsEmpty reports whether no field is set.
func (c UserContext) IsEmpty() bool {
	return c.HouseholdSize == nil && c.IncomeType == nil && c.AboutMe == nil &&
		c.Goals == nil && c.IgnoreNotes == nil && c.ResponseStyle == nil
}

// keyHint masks an API key for display: at most the first 3 and the last 4
// characters survive, and short keys show only the tail.
func keyHint(key string) string {
	r := []rune(key)
	switch {
	case len(r) >= 12:
		return string(r[:3]) + "…" + string(r[len(r)-4:])
	case len(r) >= 6:
		return "…" + string(r[len(r)-2:])
	default:
		return "…"
	}
}

// credentialAAD binds a sealed key to its owner and endpoint, so copying
// the ciphertext to another row makes it fail to open.
func credentialAAD(userID uuid.UUID, kind provider.Kind, baseURL string) []byte {
	return []byte(userID.String() + "|" + string(kind) + "|" + baseURL)
}
