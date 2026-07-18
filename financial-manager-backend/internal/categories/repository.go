package categories

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("category not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const categoryColumns = `
	id, owner_user_id, name, name_normalized, direction_scope,
	icon_media_id, color, is_system, sort_order, created_at, updated_at, archived_at
`

func scanCategory(row pgx.Row) (Category, error) {
	var c Category
	err := row.Scan(
		&c.ID, &c.OwnerUserID, &c.Name, &c.NameNormalized, &c.DirectionScope,
		&c.IconMediaID, &c.Color, &c.IsSystem, &c.SortOrder, &c.CreatedAt, &c.UpdatedAt, &c.ArchivedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Category{}, ErrNotFound
	}
	if err != nil {
		return Category{}, fmt.Errorf("scan category: %w", err)
	}
	return c, nil
}

// ListForUser returns every category visible to the user: shared system
// categories plus their own custom ones (plan.md section 14.7), ordered so
// system categories keep their curated sort_order first.
func (r *Repository) ListForUser(ctx context.Context, userID uuid.UUID) ([]Category, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+categoryColumns+`
		FROM categories
		WHERE archived_at IS NULL AND (owner_user_id IS NULL OR owner_user_id = $1)
		ORDER BY is_system DESC, sort_order ASC, name ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list categories: %w", err)
	}
	defer rows.Close()

	var out []Category
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

type CreateInput struct {
	OwnerUserID    uuid.UUID
	Name           string
	DirectionScope string
	Color          *string
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (Category, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO categories (owner_user_id, name, name_normalized, direction_scope, color, is_system, sort_order)
		VALUES ($1, $2, $3, $4, $5, FALSE, 0)
		RETURNING `+categoryColumns,
		in.OwnerUserID, in.Name, NormalizeName(in.Name), in.DirectionScope, in.Color,
	)
	return scanCategory(row)
}

// GetByIDAndVisibility fetches a category only if it's a system category or
// owned by userID — the same visibility rule as ListForUser, enforced
// before any update/delete (plan.md section 19.1).
func (r *Repository) GetByIDAndVisibility(ctx context.Context, id, userID uuid.UUID) (Category, error) {
	row := r.db.QueryRow(ctx, `
		SELECT `+categoryColumns+`
		FROM categories
		WHERE id = $1 AND archived_at IS NULL AND (owner_user_id IS NULL OR owner_user_id = $2)
	`, id, userID)
	return scanCategory(row)
}

type UpdateInput struct {
	Name           string
	DirectionScope string
	Color          *string
}

// Update only ever matches owner_user_id = userID rows — system categories
// can't be reached through this query regardless of what the caller checked
// earlier, as a second layer of defense.
func (r *Repository) Update(ctx context.Context, id, userID uuid.UUID, in UpdateInput) (Category, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE categories SET
			name = $1, name_normalized = $2, direction_scope = $3, color = $4, updated_at = now()
		WHERE id = $5 AND owner_user_id = $6 AND archived_at IS NULL
		RETURNING `+categoryColumns,
		in.Name, NormalizeName(in.Name), in.DirectionScope, in.Color, id, userID,
	)
	return scanCategory(row)
}

// Archive soft-deletes a user-owned category. Existing transactions keep
// their category_id reference; only future selection lists exclude it.
func (r *Repository) Archive(ctx context.Context, id, userID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE categories SET archived_at = now(), updated_at = now()
		WHERE id = $1 AND owner_user_id = $2 AND archived_at IS NULL
	`, id, userID)
	if err != nil {
		return fmt.Errorf("archive category: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
