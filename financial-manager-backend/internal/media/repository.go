package media

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("media asset not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const assetColumns = `
	id, owner_user_id, kind, source, source_provider, source_external_id, source_attribution,
	object_key, original_filename, mime_type, width, height, size_bytes, sha256, status,
	created_at, last_used_at, deleted_at
`

func scanAsset(row pgx.Row) (Asset, error) {
	var a Asset
	err := row.Scan(
		&a.ID, &a.OwnerUserID, &a.Kind, &a.Source, &a.SourceProvider, &a.SourceExternalID, &a.SourceAttribution,
		&a.ObjectKey, &a.OriginalFilename, &a.MimeType, &a.Width, &a.Height, &a.SizeBytes, &a.SHA256, &a.Status,
		&a.CreatedAt, &a.LastUsedAt, &a.DeletedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return Asset{}, ErrNotFound
	}
	if err != nil {
		return Asset{}, fmt.Errorf("scan media asset: %w", err)
	}
	return a, nil
}

type CreateInput struct {
	OwnerUserID       uuid.UUID
	Kind              string
	Source            string
	SourceProvider    *string
	SourceExternalID  *string
	SourceAttribution *string
	ObjectKey         string
	OriginalFilename  *string
	MimeType          string
	Width             int
	Height            int
	SizeBytes         int64
	SHA256            []byte
	Status            string
}

// CreateOrReuse inserts a new asset, or — if one with the same
// (owner_user_id, sha256) already exists and isn't deleted — reuses it and
// bumps last_used_at instead (plan.md section 16.6: "Deduplicare per utente
// e SHA-256"). Callers must delete the object they just wrote to storage
// when the returned asset's ObjectKey differs from the one they requested.
func (r *Repository) CreateOrReuse(ctx context.Context, in CreateInput) (Asset, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO media_assets (
			owner_user_id, kind, source, source_provider, source_external_id, source_attribution,
			object_key, original_filename, mime_type, width, height, size_bytes, sha256, status, last_used_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, now())
		ON CONFLICT (owner_user_id, sha256) WHERE deleted_at IS NULL
			DO UPDATE SET last_used_at = now()
		RETURNING `+assetColumns,
		in.OwnerUserID, in.Kind, in.Source, in.SourceProvider, in.SourceExternalID, in.SourceAttribution,
		in.ObjectKey, in.OriginalFilename, in.MimeType, in.Width, in.Height, in.SizeBytes, in.SHA256, in.Status,
	)
	return scanAsset(row)
}

func (r *Repository) GetByIDAndOwner(ctx context.Context, id, ownerUserID uuid.UUID) (Asset, error) {
	row := r.db.QueryRow(ctx, `
		SELECT `+assetColumns+`
		FROM media_assets WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
	`, id, ownerUserID)
	return scanAsset(row)
}

type ListFilter struct {
	OwnerUserID uuid.UUID
	Kind        string // "" = any
	SortRecent  bool   // true = ORDER BY last_used_at DESC, false = ORDER BY created_at DESC ("Libreria")
	Limit       int
}

func (r *Repository) List(ctx context.Context, filter ListFilter) ([]Asset, error) {
	limit := filter.Limit
	if limit <= 0 || limit > 100 {
		limit = 40
	}

	orderBy := "created_at DESC"
	if filter.SortRecent {
		orderBy = "last_used_at DESC NULLS LAST"
	}

	query := `SELECT ` + assetColumns + `
		FROM media_assets
		WHERE owner_user_id = $1 AND deleted_at IS NULL AND status = 'ready'`
	args := []any{filter.OwnerUserID}
	if filter.Kind != "" {
		args = append(args, filter.Kind)
		query += " AND kind = $2"
	}
	query += " ORDER BY " + orderBy + " LIMIT " + fmt.Sprintf("$%d", len(args)+1)
	args = append(args, limit)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list media assets: %w", err)
	}
	defer rows.Close()

	var out []Asset
	for rows.Next() {
		a, err := scanAsset(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// ListAllForOwner returns every non-deleted asset owned by userID,
// regardless of status or count (plan.md section 20.3 account deletion —
// unlike List, this has no page limit since it must be exhaustive for a
// purge to actually remove everything).
func (r *Repository) ListAllForOwner(ctx context.Context, ownerUserID uuid.UUID) ([]Asset, error) {
	rows, err := r.db.Query(ctx, `
		SELECT `+assetColumns+`
		FROM media_assets
		WHERE owner_user_id = $1 AND deleted_at IS NULL
	`, ownerUserID)
	if err != nil {
		return nil, fmt.Errorf("list all media assets for owner: %w", err)
	}
	defer rows.Close()

	var out []Asset
	for rows.Next() {
		a, err := scanAsset(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// MarkUsed bumps last_used_at (plan.md section 16.6: "Aggiornare
// last_used_at quando assegnato" — called whenever the asset is attached to
// a transaction, category, or profile).
func (r *Repository) MarkUsed(ctx context.Context, id, ownerUserID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE media_assets SET last_used_at = now() WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
	`, id, ownerUserID)
	if err != nil {
		return fmt.Errorf("mark media asset used: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) SoftDelete(ctx context.Context, id, ownerUserID uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE media_assets SET deleted_at = now(), status = 'deleted'
		WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
	`, id, ownerUserID)
	if err != nil {
		return fmt.Errorf("soft delete media asset: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SoftDeleteByID marks an asset deleted without an owner check — used only
// by the trusted background orphan-cleanup job (CleanupOrphans), which
// already selected the id from ListOrphans's own ownership-agnostic query.
func (r *Repository) SoftDeleteByID(ctx context.Context, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `
		UPDATE media_assets SET deleted_at = now(), status = 'deleted'
		WHERE id = $1 AND deleted_at IS NULL
	`, id)
	if err != nil {
		return fmt.Errorf("soft delete media asset by id: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// IsReferenced reports whether any row still points at this asset (plan.md
// section 16.6: "Non eliminare fisicamente un asset ancora referenziato").
func (r *Repository) IsReferenced(ctx context.Context, id uuid.UUID) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT
			EXISTS(SELECT 1 FROM users WHERE avatar_media_id = $1 AND deleted_at IS NULL)
			OR EXISTS(SELECT 1 FROM categories WHERE icon_media_id = $1 AND archived_at IS NULL)
			OR EXISTS(SELECT 1 FROM transactions WHERE media_id = $1 AND deleted_at IS NULL)
	`, id).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check media asset references: %w", err)
	}
	return exists, nil
}

// OrphanCandidate is a ready, unreferenced asset old enough to be cleaned up
// (plan.md section 16.6: "Pulire asset orfani dopo un periodo di grazia").
type OrphanCandidate struct {
	ID        uuid.UUID
	ObjectKey string
}

// ListOrphans finds assets older than olderThanHours with no referencing
// row anywhere. Kept as a single query (rather than N+1 IsReferenced calls)
// since this runs periodically over potentially many rows.
func (r *Repository) ListOrphans(ctx context.Context, olderThanHours int, limit int) ([]OrphanCandidate, error) {
	rows, err := r.db.Query(ctx, `
		SELECT m.id, m.object_key
		FROM media_assets m
		WHERE m.deleted_at IS NULL
			AND m.status = 'ready'
			AND m.created_at < now() - make_interval(hours => $1)
			AND NOT EXISTS (SELECT 1 FROM users u WHERE u.avatar_media_id = m.id AND u.deleted_at IS NULL)
			AND NOT EXISTS (SELECT 1 FROM categories c WHERE c.icon_media_id = m.id AND c.archived_at IS NULL)
			AND NOT EXISTS (SELECT 1 FROM transactions t WHERE t.media_id = m.id AND t.deleted_at IS NULL)
		LIMIT $2
	`, olderThanHours, limit)
	if err != nil {
		return nil, fmt.Errorf("list orphan media assets: %w", err)
	}
	defer rows.Close()

	var out []OrphanCandidate
	for rows.Next() {
		var c OrphanCandidate
		if err := rows.Scan(&c.ID, &c.ObjectKey); err != nil {
			return nil, fmt.Errorf("scan orphan candidate: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
