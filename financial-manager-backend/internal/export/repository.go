package export

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("export record not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const recordColumns = `id, user_id, format, status, object_key, error_message, created_at, completed_at`

func scanRecord(row pgx.Row) (Record, error) {
	var rec Record
	err := row.Scan(&rec.ID, &rec.UserID, &rec.Format, &rec.Status, &rec.ObjectKey, &rec.ErrorMessage, &rec.CreatedAt, &rec.CompletedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Record{}, ErrNotFound
	}
	if err != nil {
		return Record{}, fmt.Errorf("scan export record: %w", err)
	}
	return rec, nil
}

func (r *Repository) Create(ctx context.Context, userID uuid.UUID, format string) (Record, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO export_records (user_id, format, status)
		VALUES ($1, $2, $3)
		RETURNING `+recordColumns,
		userID, format, StatusProcessing,
	)
	return scanRecord(row)
}

func (r *Repository) GetByIDAndUserID(ctx context.Context, id, userID uuid.UUID) (Record, error) {
	row := r.db.QueryRow(ctx, `SELECT `+recordColumns+` FROM export_records WHERE id = $1 AND user_id = $2`, id, userID)
	return scanRecord(row)
}

func (r *Repository) MarkReady(ctx context.Context, id uuid.UUID, objectKey string) (Record, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE export_records SET status = $1, object_key = $2, completed_at = now()
		WHERE id = $3
		RETURNING `+recordColumns,
		StatusReady, objectKey, id,
	)
	return scanRecord(row)
}

func (r *Repository) MarkFailed(ctx context.Context, id uuid.UUID, message string) (Record, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE export_records SET status = $1, error_message = $2, completed_at = now()
		WHERE id = $3
		RETURNING `+recordColumns,
		StatusFailed, message, id,
	)
	return scanRecord(row)
}
