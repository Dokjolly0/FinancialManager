package templates

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("template not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const templateColumns = `
	id, user_id, direction, title, title_normalized,
	default_category_id, default_description, usage_count, last_used_at,
	created_at, updated_at, archived_at
`

func scanTemplate(row pgx.Row) (Template, error) {
	var t Template
	err := row.Scan(
		&t.ID, &t.UserID, &t.Direction, &t.Title, &t.TitleNormalized,
		&t.DefaultCategoryID, &t.DefaultDescription, &t.UsageCount, &t.LastUsedAt,
		&t.CreatedAt, &t.UpdatedAt, &t.ArchivedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Template{}, ErrNotFound
	}
	if err != nil {
		return Template{}, fmt.Errorf("scan template: %w", err)
	}
	return t, nil
}

type CreateInput struct {
	UserID             uuid.UUID
	Direction          string
	Title              string
	DefaultCategoryID  *uuid.UUID
	DefaultDescription *string
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (Template, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO transaction_templates (user_id, direction, title, title_normalized, default_category_id, default_description)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING `+templateColumns,
		in.UserID, in.Direction, in.Title, NormalizeTitle(in.Title), in.DefaultCategoryID, in.DefaultDescription,
	)
	return scanTemplate(row)
}

func (r *Repository) GetByIDAndUserID(ctx context.Context, id, userID uuid.UUID) (Template, error) {
	row := r.db.QueryRow(ctx, `
		SELECT `+templateColumns+`
		FROM transaction_templates WHERE id = $1 AND user_id = $2 AND archived_at IS NULL
	`, id, userID)
	return scanTemplate(row)
}

// Search powers the "Nuova operazione" title autocomplete (plan.md section
// 7.6, 17.3): filtered by direction, optionally by a title prefix, ordered
// by usage frequency and recency.
type SearchFilter struct {
	UserID    uuid.UUID
	Direction string
	Query     string // "" = no prefix filter, just the most-used templates
	Limit     int
}

func (r *Repository) Search(ctx context.Context, filter SearchFilter) ([]Template, error) {
	limit := filter.Limit
	if limit <= 0 || limit > 50 {
		limit = 10
	}

	var rows pgx.Rows
	var err error
	if filter.Query != "" {
		prefix := NormalizeTitle(filter.Query) + "%"
		rows, err = r.db.Query(ctx, `
			SELECT `+templateColumns+`
			FROM transaction_templates
			WHERE user_id = $1 AND direction = $2 AND archived_at IS NULL AND title_normalized LIKE $3
			ORDER BY usage_count DESC, last_used_at DESC NULLS LAST, title ASC
			LIMIT $4
		`, filter.UserID, filter.Direction, prefix, limit)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT `+templateColumns+`
			FROM transaction_templates
			WHERE user_id = $1 AND direction = $2 AND archived_at IS NULL
			ORDER BY usage_count DESC, last_used_at DESC NULLS LAST, title ASC
			LIMIT $3
		`, filter.UserID, filter.Direction, limit)
	}
	if err != nil {
		return nil, fmt.Errorf("search templates: %w", err)
	}
	defer rows.Close()

	var out []Template
	for rows.Next() {
		t, err := scanTemplate(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListAllForUser returns every non-archived template for userID,
// regardless of direction (plan.md section 20.2 JSON export — "modelli").
func (r *Repository) ListAllForUser(ctx context.Context, userID uuid.UUID) ([]Template, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+templateColumns+`
		FROM transaction_templates
		WHERE user_id = $1 AND archived_at IS NULL
		ORDER BY title ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list all templates for user: %w", err)
	}
	defer rows.Close()

	var out []Template
	for rows.Next() {
		t, err := scanTemplate(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

type UpdateInput struct {
	Title              string
	DefaultCategoryID  *uuid.UUID
	DefaultDescription *string
}

func (r *Repository) Update(ctx context.Context, id, userID uuid.UUID, in UpdateInput) (Template, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE transaction_templates SET
			title = $1, title_normalized = $2, default_category_id = $3, default_description = $4, updated_at = now()
		WHERE id = $5 AND user_id = $6 AND archived_at IS NULL
		RETURNING `+templateColumns,
		in.Title, NormalizeTitle(in.Title), in.DefaultCategoryID, in.DefaultDescription, id, userID,
	)
	return scanTemplate(row)
}

func (r *Repository) Archive(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE transaction_templates SET archived_at = now(), updated_at = now()
		WHERE id = $1 AND user_id = $2 AND archived_at IS NULL
	`, id, userID)
	if err != nil {
		return fmt.Errorf("archive template: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// BumpUsage records that a template was just used to create a transaction
// (plan.md section 4.4: "ordinati per frequenza e utilizzo recente"). Called
// from inside the transactions module's create/update DB transaction, so it
// takes a Querier bound to that same tx via WithQuerier.
func (r *Repository) BumpUsage(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE transaction_templates SET usage_count = usage_count + 1, last_used_at = now(), updated_at = now()
		WHERE id = $1 AND user_id = $2 AND archived_at IS NULL
	`, id, userID)
	if err != nil {
		return fmt.Errorf("bump template usage: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
