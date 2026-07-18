package transactions

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/database"
)

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
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
func (r *Repository) Create(ctx context.Context, in CreateInput) (uuid.UUID, error) {
	var id uuid.UUID
	err := r.db.QueryRow(ctx, `
		INSERT INTO transactions (
			wallet_id, user_id, direction, kind, amount_minor, currency,
			title, title_normalized, description, occurred_at, created_by_session_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id
	`,
		in.WalletID, in.UserID, in.Direction, in.Kind, in.AmountMinor, in.Currency,
		in.Title, NormalizeTitle(in.Title), in.Description, in.OccurredAt, in.CreatedBySessionID,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("insert transaction: %w", err)
	}
	return id, nil
}
