// Package export implements user data export to CSV/JSON (plan.md
// sections 7.13 "Dati", 14.2, 20.2).
package export

import (
	"time"

	"github.com/google/uuid"
)

const (
	FormatCSV  = "csv"
	FormatJSON = "json"
)

const (
	StatusProcessing = "processing"
	StatusReady      = "ready"
	StatusFailed     = "failed"
)

func IsValidFormat(format string) bool {
	return format == FormatCSV || format == FormatJSON
}

type Record struct {
	ID           uuid.UUID
	UserID       uuid.UUID
	Format       string
	Status       string
	ObjectKey    *string
	ErrorMessage *string
	CreatedAt    time.Time
	CompletedAt  *time.Time
}
