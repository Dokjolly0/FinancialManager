package wallets

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("wallet not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const walletColumns = `id, user_id, name, currency, current_balance_minor, created_at, updated_at, version, archived_at`

func scanWallet(row pgx.Row) (Wallet, error) {
	var w Wallet
	err := row.Scan(&w.ID, &w.UserID, &w.Name, &w.Currency, &w.CurrentBalanceMinor, &w.CreatedAt, &w.UpdatedAt, &w.Version, &w.ArchivedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Wallet{}, ErrNotFound
	}
	if err != nil {
		return Wallet{}, fmt.Errorf("scan wallet: %w", err)
	}
	return w, nil
}

// Create inserts the wallet with its opening balance already set — there
// is no separate "set balance" step; the caller is responsible for also
// inserting the matching OPENING_BALANCE transaction in the same DB
// transaction (plan.md section 7.3: "inizializza il saldo corrente nella
// stessa transazione database").
func (r *Repository) Create(ctx context.Context, userID uuid.UUID, currency string, openingBalanceMinor int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO wallets (user_id, currency, current_balance_minor)
		VALUES ($1, $2, $3)
		RETURNING `+walletColumns,
		userID, currency, openingBalanceMinor,
	)
	return scanWallet(row)
}

func (r *Repository) GetByUserID(ctx context.Context, userID uuid.UUID) (Wallet, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+walletColumns+` FROM wallets WHERE user_id = $1 AND archived_at IS NULL`,
		userID,
	)
	return scanWallet(row)
}

// LockForUpdate reads the wallet with FOR UPDATE, taking a row lock for
// the duration of the enclosing transaction (plan.md section 13.2/13.7:
// pessimistic lock on the wallet for every balance mutation). Must be
// called with a Repository bound to a pgx.Tx, not the pool directly.
func (r *Repository) LockForUpdate(ctx context.Context, userID uuid.UUID) (Wallet, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+walletColumns+` FROM wallets WHERE user_id = $1 AND archived_at IS NULL FOR UPDATE`,
		userID,
	)
	return scanWallet(row)
}
