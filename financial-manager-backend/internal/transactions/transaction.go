// Package transactions implements the ledger entries that move a wallet's
// balance (plan.md section 4.2, 11.10). Only what registration's opening
// balance needs exists so far — standard transaction CRUD, categories,
// templates, and media attachment land in Fase 4/5/6 of the roadmap.
package transactions

import (
	"strings"
	"time"

	"github.com/google/uuid"
)

const (
	DirectionCredit = "CREDIT"
	DirectionDebit  = "DEBIT"
)

const (
	KindStandard          = "STANDARD"
	KindOpeningBalance    = "OPENING_BALANCE"
	KindBalanceAdjustment = "BALANCE_ADJUSTMENT"
)

type Transaction struct {
	ID                 uuid.UUID
	WalletID           uuid.UUID
	UserID             uuid.UUID
	Direction          string
	Kind               string
	AmountMinor        int64
	Currency           string
	Title              string
	TitleNormalized    string
	Description        *string
	OccurredAt         time.Time
	CreatedAt          time.Time
	UpdatedAt          time.Time
	DeletedAt          *time.Time
	Version            int64
	CreatedBySessionID *uuid.UUID
}

// NormalizeTitle mirrors plan.md section 4.4: trim, compact internal
// spaces, case-insensitive comparison.
func NormalizeTitle(title string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(title)), " "))
}

// SignedDelta is the effect a transaction of this direction has on a
// wallet's balance (plan.md section 13.2).
func SignedDelta(direction string, amountMinor int64) int64 {
	if direction == DirectionDebit {
		return -amountMinor
	}
	return amountMinor
}
