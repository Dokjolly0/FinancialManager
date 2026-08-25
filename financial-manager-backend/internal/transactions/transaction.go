// Package transactions implements the ledger entries that move a wallet's
// balance (plan.md section 4.2, 11.10).
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
	KindTransfer          = "TRANSFER"
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
	CategoryID         *uuid.UUID
	TemplateID         *uuid.UUID
	MediaID            *uuid.UUID
	OccurredAt         time.Time
	CreatedAt          time.Time
	UpdatedAt          time.Time
	DeletedAt          *time.Time
	Version            int64
	CreatedBySessionID *uuid.UUID
	TransferPairID     *uuid.UUID

	// LinkedTransactionID pairs a meal-voucher expense's two DEBIT legs (the
	// voucher-wallet leg and, if the vouchers didn't cover the full expense,
	// the other-wallet leg for the shortfall) — a generic analogue of
	// TransferPairID for a pairing that stays Kind=STANDARD (so both legs
	// count in reports, unlike TRANSFER) rather than a wallet-to-wallet
	// transfer. Nil when the expense was fully covered by vouchers.
	LinkedTransactionID *uuid.UUID

	// SystemGenerated marks a row the backend wrote itself rather than in
	// response to a user action — today only the "Buoni scaduti"
	// BALANCE_ADJUSTMENT rows applyVoucherLotExpiry creates when meal-voucher
	// lots expire unused. Never editable or deletable by the user.
	SystemGenerated bool

	// PaymentGroupID groups two or more STANDARD transactions the user has
	// explicitly linked as installments of the same logical expense (e.g.
	// an acconto followed by a saldo) — migration 0029. Unlike
	// TransferPairID/LinkedTransactionID, this is not a pointer to one
	// specific sibling row: it's a shared group key with no accounting
	// effect at all. Every member keeps its own Kind=STANDARD ledger entry,
	// counts individually in reports/totals, and stays independently
	// editable/deletable — the group is purely a display/navigation
	// grouping, resolved by querying every row that shares this value.
	PaymentGroupID *uuid.UUID
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
