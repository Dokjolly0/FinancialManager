// Package wallets implements the multi-wallet portfolio (plan.md section
// 4.1, 11.6, extended post-MVP to allow more than one wallet per user).
// current_balance_minor is a denormalized projection of the transactions
// ledger, kept in sync inside the same DB transaction as every mutation
// that touches a given wallet (plan.md section 13.1).
package wallets

import (
	"time"

	"github.com/google/uuid"
)

const (
	TypeCash        = "CASH"
	TypeBank        = "BANK"
	TypeOther       = "OTHER"
	TypeMealVoucher = "MEAL_VOUCHER"
)

// DefaultName/Icon/Color seed the wallet created at registration and match
// the column defaults migration 0021 applied to every pre-multi-wallet row.
const (
	DefaultName  = "Portafoglio principale"
	DefaultIcon  = "wallet"
	DefaultColor = "#6750A4"
)

// ValidIcons is the fixed, in-app icon set wallets may reference (a string
// key, not a media asset — kept simple and offline, unlike
// categories.icon_media_id). The Flutter client owns the actual IconData
// lookup; this is server-side defense in depth against arbitrary values.
var ValidIcons = map[string]bool{
	"wallet":       true,
	"cash":         true,
	"bank":         true,
	"card":         true,
	"piggy_bank":   true,
	"safe":         true,
	"coins":        true,
	"briefcase":    true,
	"gift":         true,
	"shopping_bag": true,
	"home":         true,
	"savings":      true,
	"restaurant":   true,
}

func IsValidType(t string) bool {
	return t == TypeCash || t == TypeBank || t == TypeOther || t == TypeMealVoucher
}

func IsValidIcon(icon string) bool {
	return ValidIcons[icon]
}

type Wallet struct {
	ID                  uuid.UUID
	UserID              uuid.UUID
	Name                string
	Currency            string
	CurrentBalanceMinor int64
	Type                string
	Icon                string
	Color               string
	CreatedAt           time.Time
	UpdatedAt           time.Time
	Version             int64
	ArchivedAt          *time.Time

	// Voucher_* fields are set iff Type == TypeMealVoucher (DB-enforced,
	// migration 0024). VoucherUnitValueMinor is immutable once the wallet
	// is created (internal/wallets Service never includes it in Update) —
	// changing the face value means creating a new wallet. The three
	// expiry_* fields ARE editable later and only affect lots created
	// afterwards (see ComputeLotExpiry).
	VoucherUnitValueMinor    *int64
	VoucherExpiryCutoffMonth *int
	VoucherExpiryMonth       *int
	VoucherExpiryDay         *int
}

func (w Wallet) IsArchived() bool { return w.ArchivedAt != nil }

func (w Wallet) IsMealVoucher() bool { return w.Type == TypeMealVoucher }

// Default meal-voucher expiry policy (plan.md section 4.2): vouchers loaded
// January-August expire December 31 of the same year; loaded September-
// December, December 31 of the following year. Mirrors the common Italian
// digital-voucher issuer convention, but every wallet can override it.
const (
	DefaultVoucherExpiryCutoffMonth = 8
	DefaultVoucherExpiryMonth       = 12
	DefaultVoucherExpiryDay         = 31
)

// VoucherLot is a batch of meal vouchers loaded in one operation, all
// sharing one expires_at computed at load time (migration 0025). See
// ComputeLotExpiry for how expires_at is derived, and the
// wallet_voucher_lot_consumptions table (FIFO consumption bookkeeping) for
// how spend/removal operations draw down QuantityRemaining.
type VoucherLot struct {
	ID                     uuid.UUID
	WalletID               uuid.UUID
	QuantityTotal          int
	QuantityRemaining      int
	QuantityExpired        int
	ExpiresAt              time.Time
	CreatedByTransactionID uuid.UUID
	ExpiredByTransactionID *uuid.UUID
	CreatedAt              time.Time
}

func (l VoucherLot) IsExpiredHistory() bool { return l.QuantityExpired > 0 }

// LotConsumption records that a transaction (a voucher-expense DEBIT leg or
// a manual voucher removal) drew Quantity vouchers from a specific lot —
// the join table an edit or delete uses to know exactly what to credit
// back (migration 0026).
type LotConsumption struct {
	ID            uuid.UUID
	TransactionID uuid.UUID
	LotID         uuid.UUID
	Quantity      int
	CreatedAt     time.Time
}

// ComputeLotExpiry implements the wallet's voucher expiry policy: a lot
// loaded in a month at or before cutoffMonth expires on
// expiryMonth/expiryDay of the same year; loaded after cutoffMonth, of the
// following year. loadedAt's time-of-day is ignored — only its calendar
// date (in UTC) drives the month comparison, and the result is always
// midnight UTC on the computed date. An expiryDay that doesn't exist in
// expiryMonth (e.g. day=31, month=2) normalizes forward per time.Date's
// standard overflow behavior.
func ComputeLotExpiry(cutoffMonth, expiryMonth, expiryDay int, loadedAt time.Time) time.Time {
	loadedAt = loadedAt.UTC()
	year := loadedAt.Year()
	if int(loadedAt.Month()) > cutoffMonth {
		year++
	}
	return time.Date(year, time.Month(expiryMonth), expiryDay, 0, 0, 0, 0, time.UTC)
}

// EURDenominationsMinor is the fixed set of EUR banknote/coin values a
// wallet_cash_denominations row may reference (plan.md has no MVP mention
// of this — added for the cash-tracking feature). Includes withdrawn-from-
// issuance EUR 200/500 notes since they remain legal tender and someone
// may still hold them.
var EURDenominationsMinor = []int{
	50000, 20000, 10000, 5000, 2000, 1000, 500,
	200, 100, 50, 20, 10, 5, 2, 1,
}

func IsValidDenomination(minor int) bool {
	for _, v := range EURDenominationsMinor {
		if v == minor {
			return true
		}
	}
	return false
}

type DenominationCount struct {
	DenominationMinor int
	Count             int
	Enabled           bool
}
