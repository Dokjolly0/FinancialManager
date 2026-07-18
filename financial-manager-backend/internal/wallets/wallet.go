// Package wallets implements the single-wallet-per-user portfolio (plan.md
// section 4.1, 11.6). current_balance_minor is a denormalized projection
// of the transactions ledger, kept in sync inside the same DB transaction
// as every mutation (plan.md section 13.1).
package wallets

import (
	"time"

	"github.com/google/uuid"
)

type Wallet struct {
	ID                  uuid.UUID
	UserID              uuid.UUID
	Name                string
	Currency            string
	CurrentBalanceMinor int64
	CreatedAt           time.Time
	UpdatedAt           time.Time
	Version             int64
	ArchivedAt          *time.Time
}
