package wallets

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("wallet not found")
var ErrLotNotFound = errors.New("voucher lot not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const walletColumns = `
	id, user_id, name, currency, current_balance_minor, type, icon, color, created_at, updated_at, version, archived_at,
	voucher_unit_value_minor, voucher_expiry_cutoff_month, voucher_expiry_month, voucher_expiry_day
`

func scanWallet(row pgx.Row) (Wallet, error) {
	var w Wallet
	err := row.Scan(
		&w.ID, &w.UserID, &w.Name, &w.Currency, &w.CurrentBalanceMinor, &w.Type, &w.Icon, &w.Color,
		&w.CreatedAt, &w.UpdatedAt, &w.Version, &w.ArchivedAt,
		&w.VoucherUnitValueMinor, &w.VoucherExpiryCutoffMonth, &w.VoucherExpiryMonth, &w.VoucherExpiryDay,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Wallet{}, ErrNotFound
	}
	if err != nil {
		return Wallet{}, fmt.Errorf("scan wallet: %w", err)
	}
	return w, nil
}

// CreateRowInput is the full set of fields needed to insert a wallet row
// (named distinctly from Service's CreateInput, which is the HTTP-facing
// input and lacks the voucher fields only transactions.Service.CreateWallet
// populates). The Voucher* fields are only meaningful (and only required)
// when Type == TypeMealVoucher — see wallets.ValidateVoucherFields.
type CreateRowInput struct {
	UserID                   uuid.UUID
	Name                     string
	Currency                 string
	Type                     string
	Icon                     string
	Color                    string
	OpeningBalanceMinor      int64
	VoucherUnitValueMinor    *int64
	VoucherExpiryCutoffMonth *int
	VoucherExpiryMonth       *int
	VoucherExpiryDay         *int
}

// Create inserts the wallet with its opening balance already set — there
// is no separate "set balance" step; the caller is responsible for also
// inserting the matching OPENING_BALANCE transaction in the same DB
// transaction (plan.md section 7.3: "inizializza il saldo corrente nella
// stessa transazione database"). For a MEAL_VOUCHER wallet the caller is
// similarly responsible for inserting the first wallet_voucher_lots row
// when OpeningBalanceMinor > 0 (see transactions.Service.CreateWallet) —
// this method only writes the wallets row itself.
func (r *Repository) Create(ctx context.Context, in CreateRowInput) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO wallets (
			user_id, name, currency, current_balance_minor, type, icon, color,
			voucher_unit_value_minor, voucher_expiry_cutoff_month, voucher_expiry_month, voucher_expiry_day
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING `+walletColumns,
		in.UserID, in.Name, in.Currency, in.OpeningBalanceMinor, in.Type, in.Icon, in.Color,
		in.VoucherUnitValueMinor, in.VoucherExpiryCutoffMonth, in.VoucherExpiryMonth, in.VoucherExpiryDay,
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

// ListActiveByType returns every active (non-archived) wallet of the given
// type across all users — used by the worker's voucher-expiry sweep
// (cmd/worker), which has no single owning user to scope by.
func (r *Repository) ListActiveByType(ctx context.Context, walletType string) ([]Wallet, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+walletColumns+`
		FROM wallets
		WHERE type = $1 AND archived_at IS NULL
	`, walletType)
	if err != nil {
		return nil, fmt.Errorf("list wallets by type: %w", err)
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
	Name  string
	Type  string
	Icon  string
	Color string

	// Editable only for a wallet that is (and stays) MEAL_VOUCHER — nil for
	// every other type, since the columns are nil at the DB level too.
	// VoucherUnitValueMinor is deliberately absent: it is immutable after
	// creation (see wallet.go), so Update never writes that column.
	VoucherExpiryCutoffMonth *int
	VoucherExpiryMonth       *int
	VoucherExpiryDay         *int
}

func (r *Repository) Update(ctx context.Context, id, userID uuid.UUID, in UpdateInput, expectedVersion int64) (Wallet, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE wallets SET
			name = $1, type = $2, icon = $3, color = $4,
			voucher_expiry_cutoff_month = $5, voucher_expiry_month = $6, voucher_expiry_day = $7,
			updated_at = now(), version = version + 1
		WHERE id = $8 AND user_id = $9 AND version = $10 AND archived_at IS NULL
		RETURNING `+walletColumns,
		in.Name, in.Type, in.Icon, in.Color,
		in.VoucherExpiryCutoffMonth, in.VoucherExpiryMonth, in.VoucherExpiryDay,
		id, userID, expectedVersion,
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

// --- Meal voucher lots ---------------------------------------------------

const voucherLotColumns = `
	id, wallet_id, quantity_total, quantity_remaining, quantity_expired, expires_at,
	created_by_transaction_id, expired_by_transaction_id, created_at
`

func scanVoucherLot(row pgx.Row) (VoucherLot, error) {
	var l VoucherLot
	err := row.Scan(
		&l.ID, &l.WalletID, &l.QuantityTotal, &l.QuantityRemaining, &l.QuantityExpired, &l.ExpiresAt,
		&l.CreatedByTransactionID, &l.ExpiredByTransactionID, &l.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return VoucherLot{}, ErrLotNotFound
	}
	if err != nil {
		return VoucherLot{}, fmt.Errorf("scan voucher lot: %w", err)
	}
	return l, nil
}

// CreateVoucherLot inserts a new lot with quantity_remaining == quantity_total
// (nothing consumed yet). Callers compute expiresAt via ComputeLotExpiry
// before calling this.
func (r *Repository) CreateVoucherLot(ctx context.Context, walletID uuid.UUID, quantity int, expiresAt time.Time, createdByTransactionID uuid.UUID) (VoucherLot, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO wallet_voucher_lots (wallet_id, quantity_total, quantity_remaining, expires_at, created_by_transaction_id)
		VALUES ($1, $2, $2, $3, $4)
		RETURNING `+voucherLotColumns,
		walletID, quantity, expiresAt, createdByTransactionID,
	)
	return scanVoucherLot(row)
}

// LockActiveLotsForUpdate returns every lot with quantity_remaining > 0,
// oldest expires_at first (the FIFO consumption order), each row-locked for
// the rest of the caller's DB transaction. Must be called after the wallet
// itself is already locked (LockByIDForUpdate) — lots are always scoped to
// one already-locked wallet, so this adds no new deadlock risk despite
// taking further row locks in the same transaction.
func (r *Repository) LockActiveLotsForUpdate(ctx context.Context, walletID uuid.UUID) ([]VoucherLot, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+voucherLotColumns+`
		FROM wallet_voucher_lots
		WHERE wallet_id = $1 AND quantity_remaining > 0
		ORDER BY expires_at ASC, id ASC
		FOR UPDATE
	`, walletID)
	if err != nil {
		return nil, fmt.Errorf("lock active voucher lots: %w", err)
	}
	defer rows.Close()

	var out []VoucherLot
	for rows.Next() {
		l, err := scanVoucherLot(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// ListLots returns every lot for a wallet (active and expired history),
// oldest expires_at first — the UI buckets them into active/expiring-soon/
// expired client-side (or the caller can filter server-side, see
// CountLotsExpiringBy for the wallet-list badge).
func (r *Repository) ListLots(ctx context.Context, walletID uuid.UUID) ([]VoucherLot, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+voucherLotColumns+`
		FROM wallet_voucher_lots
		WHERE wallet_id = $1
		ORDER BY expires_at ASC, id ASC
	`, walletID)
	if err != nil {
		return nil, fmt.Errorf("list voucher lots: %w", err)
	}
	defer rows.Close()

	var out []VoucherLot
	for rows.Next() {
		l, err := scanVoucherLot(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, l)
	}
	return out, rows.Err()
}

// CountLotsExpiringBy counts active lots (quantity_remaining > 0) whose
// expires_at falls on or before thresholdDate — used for the wallet list's
// "expiring soon" badge without loading every lot.
func (r *Repository) CountLotsExpiringBy(ctx context.Context, walletID uuid.UUID, thresholdDate time.Time) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM wallet_voucher_lots
		WHERE wallet_id = $1 AND quantity_remaining > 0 AND expires_at <= $2
	`, walletID, thresholdDate).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count voucher lots expiring by: %w", err)
	}
	return count, nil
}

// LockLotForUpdate locks one lot by ID, for edit/delete/reversal flows that
// already know which lot(s) to touch (e.g. from ConsumptionsForTransaction)
// rather than walking the active-lots FIFO order. Caller must already hold
// the wallet lock.
func (r *Repository) LockLotForUpdate(ctx context.Context, lotID uuid.UUID) (VoucherLot, error) {
	row := r.db.QueryRow(ctx, `SELECT `+voucherLotColumns+` FROM wallet_voucher_lots WHERE id = $1 FOR UPDATE`, lotID)
	return scanVoucherLot(row)
}

// LockLotByCreatingTransactionForUpdate finds and locks the lot a given
// voucher-credit transaction created — used to edit/delete that credit.
func (r *Repository) LockLotByCreatingTransactionForUpdate(ctx context.Context, transactionID uuid.UUID) (VoucherLot, error) {
	row := r.db.QueryRow(ctx, `
		SELECT `+voucherLotColumns+` FROM wallet_voucher_lots WHERE created_by_transaction_id = $1 FOR UPDATE
	`, transactionID)
	return scanVoucherLot(row)
}

// UpdateLotRemaining sets quantity_remaining directly — used by FIFO
// consumption/reversal (spend, manual removal, and their edits/deletes),
// which computes the new value from the current one plus/minus a delta.
func (r *Repository) UpdateLotRemaining(ctx context.Context, lotID uuid.UUID, newRemaining int) error {
	tag, err := r.db.Exec(ctx, `UPDATE wallet_voucher_lots SET quantity_remaining = $1 WHERE id = $2`, newRemaining, lotID)
	if err != nil {
		return fmt.Errorf("update voucher lot remaining: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrLotNotFound
	}
	return nil
}

// UpdateLotQuantityAndExpiry adjusts a lot's quantity_total/quantity_remaining
// (by the same delta, preserving whatever was already consumed) and
// expires_at together — used when editing an existing voucher-credit
// transaction's quantity and/or load date.
func (r *Repository) UpdateLotQuantityAndExpiry(ctx context.Context, lotID uuid.UUID, newTotal, newRemaining int, newExpiresAt time.Time) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE wallet_voucher_lots SET quantity_total = $1, quantity_remaining = $2, expires_at = $3
		WHERE id = $4
	`, newTotal, newRemaining, newExpiresAt, lotID)
	if err != nil {
		return fmt.Errorf("update voucher lot quantity and expiry: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrLotNotFound
	}
	return nil
}

// MarkLotExpired records an expiry write-off: quantity_remaining drops to
// zero, quantity_expired is set to however much was lost, and
// expired_by_transaction_id points at the system-generated "Buoni scaduti"
// row that realized the loss. Called only by applyVoucherLotExpiry.
func (r *Repository) MarkLotExpired(ctx context.Context, lotID uuid.UUID, expiredQuantity int, expiredByTransactionID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE wallet_voucher_lots
		SET quantity_remaining = 0, quantity_expired = $1, expired_by_transaction_id = $2
		WHERE id = $3
	`, expiredQuantity, expiredByTransactionID, lotID)
	if err != nil {
		return fmt.Errorf("mark voucher lot expired: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrLotNotFound
	}
	return nil
}

// DeleteLot removes a lot outright — only valid for a credit that was never
// consumed (quantity_remaining == quantity_total) and is now itself being
// deleted or fully replaced by an edit.
func (r *Repository) DeleteLot(ctx context.Context, lotID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM wallet_voucher_lots WHERE id = $1`, lotID)
	if err != nil {
		return fmt.Errorf("delete voucher lot: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrLotNotFound
	}
	return nil
}

// --- Meal voucher lot consumptions ----------------------------------------

const lotConsumptionColumns = `id, transaction_id, lot_id, quantity, created_at`

func scanLotConsumption(row pgx.Row) (LotConsumption, error) {
	var c LotConsumption
	err := row.Scan(&c.ID, &c.TransactionID, &c.LotID, &c.Quantity, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return LotConsumption{}, ErrLotNotFound
	}
	if err != nil {
		return LotConsumption{}, fmt.Errorf("scan lot consumption: %w", err)
	}
	return c, nil
}

// RecordLotConsumption logs that transactionID drew quantity vouchers from
// lotID — the caller must have already reduced that lot's
// quantity_remaining via UpdateLotRemaining in the same DB transaction.
func (r *Repository) RecordLotConsumption(ctx context.Context, transactionID, lotID uuid.UUID, quantity int) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO wallet_voucher_lot_consumptions (transaction_id, lot_id, quantity)
		VALUES ($1, $2, $3)
	`, transactionID, lotID, quantity)
	if err != nil {
		return fmt.Errorf("record lot consumption: %w", err)
	}
	return nil
}

// ConsumptionsForTransaction returns every lot a transaction drew from —
// used to reverse a spend/removal on edit or delete (credit the quantities
// back to their lots) before it's known whether the transaction will be
// re-applied with new inputs or dropped entirely.
func (r *Repository) ConsumptionsForTransaction(ctx context.Context, transactionID uuid.UUID) ([]LotConsumption, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+lotConsumptionColumns+` FROM wallet_voucher_lot_consumptions WHERE transaction_id = $1
	`, transactionID)
	if err != nil {
		return nil, fmt.Errorf("list lot consumptions for transaction: %w", err)
	}
	defer rows.Close()

	var out []LotConsumption
	for rows.Next() {
		c, err := scanLotConsumption(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// DeleteLotConsumptionsForTransaction removes every consumption row for a
// transaction — called once the quantities have been credited back to
// their lots (reversal), so a later re-application starts from a clean
// slate.
func (r *Repository) DeleteLotConsumptionsForTransaction(ctx context.Context, transactionID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM wallet_voucher_lot_consumptions WHERE transaction_id = $1`, transactionID)
	if err != nil {
		return fmt.Errorf("delete lot consumptions for transaction: %w", err)
	}
	return nil
}
