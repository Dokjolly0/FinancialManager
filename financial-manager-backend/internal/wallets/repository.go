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

const walletColumns = `id, user_id, name, currency, current_balance_minor, type, icon, color, created_at, updated_at, version, archived_at`

func scanWallet(row pgx.Row) (Wallet, error) {
	var w Wallet
	err := row.Scan(
		&w.ID, &w.UserID, &w.Name, &w.Currency, &w.CurrentBalanceMinor, &w.Type, &w.Icon, &w.Color,
		&w.CreatedAt, &w.UpdatedAt, &w.Version, &w.ArchivedAt,
	)
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
func (r *Repository) Create(ctx context.Context, userID uuid.UUID, name, currency, walletType, icon, color string, openingBalanceMinor int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO wallets (user_id, name, currency, current_balance_minor, type, icon, color)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING `+walletColumns,
		userID, name, currency, openingBalanceMinor, walletType, icon, color,
	)
	return scanWallet(row)
}

// ListByUserID returns every active (non-archived) wallet for a user,
// oldest first — the natural "creation order" a wallet list/picker shows.
func (r *Repository) ListByUserID(ctx context.Context, userID uuid.UUID) ([]Wallet, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+walletColumns+`
		FROM wallets
		WHERE user_id = $1 AND archived_at IS NULL
		ORDER BY created_at ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list wallets: %w", err)
	}
	defer rows.Close()

	var out []Wallet
	for rows.Next() {
		w, err := scanWallet(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, rows.Err()
}

// ListAllByUserID returns every wallet for a user, active or archived,
// oldest first. Used where historical data must never disappear just
// because its wallet was archived — e.g. the "all wallets" aggregate in
// reports/export (plan.md's wallet selector), unlike ListByUserID which is
// for pickers that only offer wallets still open for new activity.
func (r *Repository) ListAllByUserID(ctx context.Context, userID uuid.UUID) ([]Wallet, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+walletColumns+`
		FROM wallets
		WHERE user_id = $1
		ORDER BY created_at ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list all wallets: %w", err)
	}
	defer rows.Close()

	var out []Wallet
	for rows.Next() {
		w, err := scanWallet(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, rows.Err()
}

// GetByID enforces ownership: the wallet must belong to userID, active or
// archived (archived wallets remain readable for history/reports).
func (r *Repository) GetByID(ctx context.Context, id, userID uuid.UUID) (Wallet, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+walletColumns+` FROM wallets WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	return scanWallet(row)
}

// GetByUserID returns the user's oldest active wallet. Kept for legacy
// single-wallet call sites (e.g. the auth response snapshot) that haven't
// migrated to ListByUserID/GetByID yet — the explicit ORDER BY/LIMIT makes
// it deterministic now that a user may have more than one active wallet,
// where it previously relied on there only ever being at most one row.
func (r *Repository) GetByUserID(ctx context.Context, userID uuid.UUID) (Wallet, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+walletColumns+` FROM wallets WHERE user_id = $1 AND archived_at IS NULL ORDER BY created_at ASC LIMIT 1`,
		userID,
	)
	return scanWallet(row)
}

// LockByIDForUpdate reads one wallet with FOR UPDATE, ownership- and
// archived-checked in the WHERE clause so a cross-user or archived
// reference simply locks no row (ErrNotFound) rather than silently
// operating on the wrong wallet. Must be called with a Repository bound to
// a pgx.Tx, not the pool directly (plan.md section 13.2/13.7: pessimistic
// lock on the wallet for every balance mutation).
func (r *Repository) LockByIDForUpdate(ctx context.Context, walletID, userID uuid.UUID) (Wallet, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+walletColumns+` FROM wallets WHERE id = $1 AND user_id = $2 AND archived_at IS NULL FOR UPDATE`,
		walletID, userID,
	)
	return scanWallet(row)
}

type UpdateInput struct {
	Name string
	Type string
	Icon string
	Color string
}

func (r *Repository) Update(ctx context.Context, id, userID uuid.UUID, in UpdateInput, expectedVersion int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE wallets SET name = $1, type = $2, icon = $3, color = $4, updated_at = now(), version = version + 1
		WHERE id = $5 AND user_id = $6 AND version = $7 AND archived_at IS NULL
		RETURNING `+walletColumns,
		in.Name, in.Type, in.Icon, in.Color, id, userID, expectedVersion,
	)
	return scanWallet(row)
}

// Archive soft-deletes a wallet (plan.md-style soft delete, mirroring
// categories.Archive). Never hard-deleted: its transaction history must
// stay intact for reports/export. Callers are responsible for any
// non-zero-balance confirmation — this method archives unconditionally.
func (r *Repository) Archive(ctx context.Context, id, userID uuid.UUID, expectedVersion int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE wallets SET archived_at = now(), updated_at = now(), version = version + 1
		WHERE id = $1 AND user_id = $2 AND version = $3 AND archived_at IS NULL
		RETURNING `+walletColumns,
		id, userID, expectedVersion,
	)
	return scanWallet(row)
}

// UpdateBalance applies the new denormalized balance. expectedVersion is
// the version read under the same row lock (LockByIDForUpdate) — since no
// concurrent writer can have changed it in between, a mismatch here would
// indicate a logic bug, not a real race, but checking costs nothing and
// keeps the invariant explicit.
func (r *Repository) UpdateBalance(ctx context.Context, walletID uuid.UUID, newBalanceMinor int64, expectedVersion int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE wallets SET current_balance_minor = $1, updated_at = now(), version = version + 1
		WHERE id = $2 AND version = $3
		RETURNING `+walletColumns,
		newBalanceMinor, walletID, expectedVersion,
	)
	return scanWallet(row)
}

// --- Cash denominations ------------------------------------------------

// GetDenominations always returns the full fixed EUR denomination set,
// merging stored rows with count=0/enabled=true defaults for any
// denomination the wallet hasn't customized yet — the editor screen
// renders one row per denomination regardless of DB state.
func (r *Repository) GetDenominations(ctx context.Context, walletID uuid.UUID) ([]DenominationCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT denomination_minor, count, enabled FROM wallet_cash_denominations WHERE wallet_id = $1`,
		walletID,
	)
	if err != nil {
		return nil, fmt.Errorf("query denominations: %w", err)
	}
	defer rows.Close()

	stored := make(map[int]DenominationCount)
	for rows.Next() {
		var d DenominationCount
		if err := rows.Scan(&d.DenominationMinor, &d.Count, &d.Enabled); err != nil {
			return nil, fmt.Errorf("scan denomination: %w", err)
		}
		stored[d.DenominationMinor] = d
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	out := make([]DenominationCount, 0, len(EURDenominationsMinor))
	for _, v := range EURDenominationsMinor {
		if d, ok := stored[v]; ok {
			out = append(out, d)
		} else {
			out = append(out, DenominationCount{DenominationMinor: v, Count: 0, Enabled: true})
		}
	}
	return out, nil
}

// ReplaceDenominations upserts the full breakdown in one atomic statement
// (a single SQL statement needs no explicit transaction) — the editor
// screen always saves the whole set, not incremental deltas. Purely
// informational: never validated against or used to derive
// current_balance_minor.
func (r *Repository) ReplaceDenominations(ctx context.Context, walletID uuid.UUID, counts []DenominationCount) error {
	minors := make([]int32, len(counts))
	countVals := make([]int32, len(counts))
	enabledVals := make([]bool, len(counts))
	for i, c := range counts {
		if !IsValidDenomination(c.DenominationMinor) {
			return fmt.Errorf("invalid denomination_minor: %d", c.DenominationMinor)
		}
		minors[i] = int32(c.DenominationMinor)
		countVals[i] = int32(c.Count)
		enabledVals[i] = c.Enabled
	}

	_, err := r.db.Exec(ctx, `
		INSERT INTO wallet_cash_denominations (wallet_id, denomination_minor, count, enabled, updated_at)
		SELECT $1, d, c, e, now()
		FROM unnest($2::int[], $3::int[], $4::bool[]) AS t(d, c, e)
		ON CONFLICT (wallet_id, denomination_minor)
		DO UPDATE SET count = EXCLUDED.count, enabled = EXCLUDED.enabled, updated_at = now()
	`, walletID, minors, countVals, enabledVals)
	if err != nil {
		return fmt.Errorf("replace denominations: %w", err)
	}
	return nil
}
