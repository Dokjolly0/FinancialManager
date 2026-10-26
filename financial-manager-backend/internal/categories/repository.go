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
// categories plus their own custom ones (plan.md section 14.7), each with
// how many of the user's live transactions use it (for the "most used"
// ordering and the delete warning) and whether the user hid it. Hidden
// categories are still returned: history, exports and the restore action
// need their names; pickers leave them out. Ordered alphabetically, which
// is also the clients' default ordering.
func (r *Repository) ListForUser(ctx context.Context, userID uuid.UUID) ([]Category, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+categoryColumns+`,
			(SELECT COUNT(*) FROM transactions t
				WHERE t.user_id = $1 AND t.category_id = categories.id AND t.deleted_at IS NULL) AS usage_count,
			EXISTS (SELECT 1 FROM user_hidden_categories h
				WHERE h.user_id = $1 AND h.category_id = categories.id) AS hidden
		FROM categories
		WHERE archived_at IS NULL AND (owner_user_id IS NULL OR owner_user_id = $1)
		ORDER BY name_normalized ASC, direction_scope ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list categories: %w", err)
	}
	defer rows.Close()

	var out []Category
	for rows.Next() {
		var c Category
		if err := rows.Scan(
			&c.ID, &c.OwnerUserID, &c.Name, &c.NameNormalized, &c.DirectionScope,
			&c.IconMediaID, &c.Color, &c.IsSystem, &c.SortOrder, &c.CreatedAt, &c.UpdatedAt, &c.ArchivedAt,
			&c.UsageCount, &c.Hidden,
		); err != nil {
			return nil, fmt.Errorf("scan category: %w", err)
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

// ClearIconMediaForOwner detaches every custom-category icon reference for
// userID (plan.md section 20.3 account deletion — see
// media.Repository.IsReferenced, mirroring transactions.ClearMediaForUser).
func (r *Repository) ClearIconMediaForOwner(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE categories SET icon_media_id = NULL WHERE owner_user_id = $1`, userID)
	if err != nil {
		return fmt.Errorf("clear category icon media for owner: %w", err)
	}
	return nil
}

// Archive soft-deletes a user-owned category. Service.Delete detaches it
// from the user's transactions and templates first, in the same DB
// transaction.
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

// DetachFromTransactions clears category_id on every transaction of userID
// filed under the category — soft-deleted ones included, so nothing keeps
// pointing at an archived category — and returns the wallets touched, whose
// cached reports must be invalidated. version is bumped like any other
// edit, so an edit form opened before the delete can't save the old
// category back (it gets a stale-version conflict instead).
func (r *Repository) DetachFromTransactions(ctx context.Context, id, userID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, `
		WITH detached AS (
			UPDATE transactions SET category_id = NULL, version = version + 1, updated_at = now()
			WHERE user_id = $2 AND category_id = $1
			RETURNING wallet_id
		)
		SELECT DISTINCT wallet_id FROM detached
	`, id, userID)
	if err != nil {
		return nil, fmt.Errorf("detach category from transactions: %w", err)
	}
	defer rows.Close()

	var walletIDs []uuid.UUID
	for rows.Next() {
		var walletID uuid.UUID
		if err := rows.Scan(&walletID); err != nil {
			return nil, fmt.Errorf("scan detached wallet: %w", err)
		}
		walletIDs = append(walletIDs, walletID)
	}
	return walletIDs, rows.Err()
}

// DetachFromTemplates clears the category as the default of userID's
// transaction templates, so a template doesn't keep suggesting it.
func (r *Repository) DetachFromTemplates(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE transaction_templates SET default_category_id = NULL, updated_at = now()
		WHERE user_id = $2 AND default_category_id = $1
	`, id, userID)
	if err != nil {
		return fmt.Errorf("detach category from templates: %w", err)
	}
	return nil
}

// Hide hides a category from userID's pickers. Idempotent.
func (r *Repository) Hide(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO user_hidden_categories (user_id, category_id) VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, userID, id)
	if err != nil {
		return fmt.Errorf("hide category: %w", err)
	}
	return nil
}

// Unhide shows a hidden category in userID's pickers again. Idempotent.
func (r *Repository) Unhide(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM user_hidden_categories WHERE user_id = $1 AND category_id = $2`, userID, id)
	if err != nil {
		return fmt.Errorf("unhide category: %w", err)
	}
	return nil
}
