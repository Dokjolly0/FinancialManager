// Package categories implements economic classification of transactions
// (plan.md section 4.1, 11.7) — a shared set of system categories plus
// each user's own custom ones.
package categories

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	ScopeDebit  = "DEBIT"
	ScopeCredit = "CREDIT"
	ScopeBoth   = "BOTH"
)

type Category struct {
	ID             uuid.UUID
	OwnerUserID    *uuid.UUID
	Name           string
	NameNormalized string
	DirectionScope string
	IconMediaID    *uuid.UUID
	Color          *string
	IsSystem       bool
	SortOrder      int
	CreatedAt      time.Time
	UpdatedAt      time.Time
	ArchivedAt     *time.Time
}

// NormalizeName mirrors plan.md section 4.4's title normalization: trim,
// compact internal spaces, case-insensitive comparison.
func NormalizeName(name string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(name)), " "))
}

func IsValidScope(scope string) bool {
	return scope == ScopeDebit || scope == ScopeCredit || scope == ScopeBoth
}

// Matches reports whether the category can be used for a transaction with
// the given direction (plan.md section 7.6: "modelli di uscita per uscite,
// di entrata per entrate" — the same filtering rule applies to categories).
func (c Category) Matches(direction string) bool {
	return c.DirectionScope == ScopeBoth || c.DirectionScope == direction
}
