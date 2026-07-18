package transactions

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("transaction not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const transactionColumns = `
	id, wallet_id, user_id, direction, kind, amount_minor, currency,
	title, title_normalized, description, occurred_at,
	created_at, updated_at, deleted_at, version, created_by_session_id
`

func scanTransaction(row pgx.Row) (Transaction, error) {
	var t Transaction
	err := row.Scan(
		&t.ID, &t.WalletID, &t.UserID, &t.Direction, &t.Kind, &t.AmountMinor, &t.Currency,
		&t.Title, &t.TitleNormalized, &t.Description, &t.OccurredAt,
		&t.CreatedAt, &t.UpdatedAt, &t.DeletedAt, &t.Version, &t.CreatedBySessionID,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Transaction{}, ErrNotFound
	}
	if err != nil {
		return Transaction{}, fmt.Errorf("scan transaction: %w", err)
	}
	return t, nil
}

type CreateInput struct {
	WalletID           uuid.UUID
	UserID             uuid.UUID
	Direction          string
	Kind               string
	AmountMinor        int64
	Currency           string
	Title              string
	Description        *string
	OccurredAt         time.Time
	CreatedBySessionID *uuid.UUID
}

// Create inserts a ledger entry. Callers are responsible for updating the
// wallet's denormalized balance in the same DB transaction (plan.md
// section 13.2) — this method only appends to the ledger.
func (r *Repository) Create(ctx context.Context, in CreateInput) (Transaction, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO transactions (
			wallet_id, user_id, direction, kind, amount_minor, currency,
			title, title_normalized, description, occurred_at, created_by_session_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING `+transactionColumns,
		in.WalletID, in.UserID, in.Direction, in.Kind, in.AmountMinor, in.Currency,
		in.Title, NormalizeTitle(in.Title), in.Description, in.OccurredAt, in.CreatedBySessionID,
	)
	return scanTransaction(row)
}

// GetByIDAndUserID enforces plan.md section 19.1: never resolve a
// transaction by ID alone — always scope to the authenticated owner.
func (r *Repository) GetByIDAndUserID(ctx context.Context, id, userID uuid.UUID) (Transaction, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+transactionColumns+` FROM transactions WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		id, userID,
	)
	return scanTransaction(row)
}

// LockByIDAndUserID reads the row with FOR UPDATE for use inside a
// mutation transaction (plan.md section 13.3/13.4), after the wallet lock
// is already held.
func (r *Repository) LockByIDAndUserID(ctx context.Context, id, userID uuid.UUID) (Transaction, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+transactionColumns+` FROM transactions WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL FOR UPDATE`,
		id, userID,
	)
	return scanTransaction(row)
}

type UpdateInput struct {
	Direction   string
	AmountMinor int64
	Title       string
	Description *string
	OccurredAt  time.Time
}

// Update requires the caller-supplied version to match the current row
// (optimistic concurrency, plan.md section 7.11/26.3). Returns ErrNotFound
// if the row doesn't exist, is deleted, or the version doesn't match —
// callers that already loaded the row can distinguish "gone" from
// "conflict" by re-fetching.
func (r *Repository) Update(ctx context.Context, id, userID uuid.UUID, expectedVersion int64, in UpdateInput) (Transaction, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE transactions SET
			direction = $1, amount_minor = $2, title = $3, title_normalized = $4,
			description = $5, occurred_at = $6, updated_at = now(), version = version + 1
		WHERE id = $7 AND user_id = $8 AND version = $9 AND deleted_at IS NULL
		RETURNING `+transactionColumns,
		in.Direction, in.AmountMinor, in.Title, NormalizeTitle(in.Title),
		in.Description, in.OccurredAt, id, userID, expectedVersion,
	)
	return scanTransaction(row)
}

// SoftDelete marks the transaction deleted; it no longer contributes to
// the balance or ordinary listings (plan.md section 13.4).
func (r *Repository) SoftDelete(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE transactions SET deleted_at = now(), version = version + 1
		WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
	`, id, userID)
	if err != nil {
		return fmt.Errorf("soft delete transaction: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SumNetForWallet computes the ledger's net contribution to the wallet
// balance from scratch — the reconciliation control in plan.md section
// 13.6, compared against the denormalized wallets.current_balance_minor.
func (r *Repository) SumNetForWallet(ctx context.Context, walletID uuid.UUID) (int64, error) {
	var net int64
	err := r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_minor ELSE -amount_minor END), 0)
		FROM transactions
		WHERE wallet_id = $1 AND deleted_at IS NULL
	`, walletID).Scan(&net)
	if err != nil {
		return 0, fmt.Errorf("sum net for wallet: %w", err)
	}
	return net, nil
}

// ListFilter selects and paginates a user's ledger (plan.md section 17).
// Cursor pagination only (no offset): stable under concurrent inserts and
// fast on long histories.
type ListFilter struct {
	UserID    uuid.UUID
	Direction string // "" = any
	Kind      string // "" = any
	Limit     int
	Cursor    string // opaque, from PageInfo.NextCursor
}

type Page struct {
	Transactions []Transaction
	NextCursor   string
	HasMore      bool
}

func encodeCursor(occurredAt time.Time, id uuid.UUID) string {
	raw := occurredAt.UTC().Format(time.RFC3339Nano) + "|" + id.String()
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func decodeCursor(cursor string) (time.Time, uuid.UUID, error) {
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor encoding: %w", err)
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor format")
	}
	occurredAt, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor timestamp: %w", err)
	}
	id, err := uuid.Parse(parts[1])
	if err != nil {
		return time.Time{}, uuid.Nil, fmt.Errorf("invalid cursor id: %w", err)
	}
	return occurredAt, id, nil
}

func (r *Repository) List(ctx context.Context, filter ListFilter) (Page, error) {
	limit := filter.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	var (
		conditions = []string{"user_id = $1", "deleted_at IS NULL"}
		args       = []any{filter.UserID}
	)

	if filter.Direction != "" {
		args = append(args, filter.Direction)
		conditions = append(conditions, "direction = $"+strconv.Itoa(len(args)))
	}
	if filter.Kind != "" {
		args = append(args, filter.Kind)
		conditions = append(conditions, "kind = $"+strconv.Itoa(len(args)))
	}
	if filter.Cursor != "" {
		occurredAt, id, err := decodeCursor(filter.Cursor)
		if err != nil {
			return Page{}, err
		}
		args = append(args, occurredAt, id)
		occurredAtIdx := len(args) - 1
		idIdx := len(args)
		conditions = append(conditions, fmt.Sprintf(
			"(occurred_at, id) < ($%d, $%d)", occurredAtIdx, idIdx,
		))
	}

	args = append(args, limit+1)
	query := `SELECT ` + transactionColumns + `
		FROM transactions
		WHERE ` + strings.Join(conditions, " AND ") + `
		ORDER BY occurred_at DESC, id DESC
		LIMIT $` + strconv.Itoa(len(args))

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return Page{}, fmt.Errorf("list transactions: %w", err)
	}
	defer rows.Close()

	var results []Transaction
	for rows.Next() {
		t, err := scanTransaction(rows)
		if err != nil {
			return Page{}, err
		}
		results = append(results, t)
	}
	if err := rows.Err(); err != nil {
		return Page{}, fmt.Errorf("iterate transactions: %w", err)
	}

	hasMore := len(results) > limit
	if hasMore {
		results = results[:limit]
	}

	page := Page{Transactions: results, HasMore: hasMore}
	if hasMore && len(results) > 0 {
		last := results[len(results)-1]
		page.NextCursor = encodeCursor(last.OccurredAt, last.ID)
	}
	return page, nil
}
