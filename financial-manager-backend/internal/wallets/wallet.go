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
	TypeCash  = "CASH"
	TypeBank  = "BANK"
	TypeOther = "OTHER"
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
}

func IsValidType(t string) bool {
	return t == TypeCash || t == TypeBank || t == TypeOther
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
}

func (w Wallet) IsArchived() bool { return w.ArchivedAt != nil }

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
