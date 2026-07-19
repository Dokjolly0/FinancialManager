// Package media implements image storage, upload processing, and search
// (plan.md section 4.1, 11.8, 16). PostgreSQL stores only metadata; the
// actual bytes live in the object store (internal/platform/storage).
package media

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	KindProfile     = "profile"
	KindTransaction = "transaction"
	KindCategory    = "category"
)

const (
	SourceUpload          = "upload"
	SourceSearch          = "search"
	SourceGeneratedImport = "generated-import"
)

const (
	StatusProcessing = "processing"
	StatusReady      = "ready"
	StatusRejected   = "rejected"
	StatusDeleted    = "deleted"
)

func IsValidKind(kind string) bool {
	return kind == KindProfile || kind == KindTransaction || kind == KindCategory
}

// normalizeMediaName mirrors categories.NormalizeName: trim, compact
// internal spaces, case-insensitive comparison — used for search matching.
func normalizeMediaName(name string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(name)), " "))
}

type Asset struct {
	ID                uuid.UUID
	OwnerUserID       uuid.UUID
	Kind              string
	Source            string
	SourceProvider    *string
	SourceExternalID  *string
	SourceAttribution *string
	ObjectKey         string
	OriginalFilename  *string
	Name              *string
	NameNormalized    *string
	MimeType          string
	Width             int
	Height            int
	SizeBytes         int64
	SHA256            []byte
	Status            string
	CreatedAt         time.Time
	LastUsedAt        *time.Time
	DeletedAt         *time.Time
}
