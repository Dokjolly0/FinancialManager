// Package templates implements transaction templates (plan.md section 4.1,
// 11.9) — reusable title/category/description bundles for frequent
// operations, surfaced as title autocomplete in the "Nuova operazione"
// screen (plan.md section 7.6).
package templates

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

type Template struct {
	ID                 uuid.UUID
	UserID             uuid.UUID
	Direction          string
	Title              string
	TitleNormalized    string
	DefaultCategoryID  *uuid.UUID
	DefaultDescription *string
	UsageCount         int64
	LastUsedAt         *time.Time
	CreatedAt          time.Time
	UpdatedAt          time.Time
	ArchivedAt         *time.Time
}

// NormalizeTitle mirrors transactions.NormalizeTitle (plan.md section 4.4).
func NormalizeTitle(title string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(title)), " "))
}
