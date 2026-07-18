package identities

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("external identity not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const identityColumns = `id, user_id, provider, provider_subject, provider_email, provider_email_verified, linked_at, last_used_at`

func scanIdentity(row pgx.Row) (ExternalIdentity, error) {
	var e ExternalIdentity
	err := row.Scan(&e.ID, &e.UserID, &e.Provider, &e.ProviderSubject, &e.ProviderEmail, &e.ProviderEmailVerified, &e.LinkedAt, &e.LastUsedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return ExternalIdentity{}, ErrNotFound
	}
	if err != nil {
		return ExternalIdentity{}, fmt.Errorf("scan external identity: %w", err)
	}
	return e, nil
}

type CreateInput struct {
	UserID                uuid.UUID
	Provider              string
	ProviderSubject       string
	ProviderEmail         *string
	ProviderEmailVerified *bool
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (ExternalIdentity, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO external_identities (user_id, provider, provider_subject, provider_email, provider_email_verified)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING `+identityColumns,
		in.UserID, in.Provider, in.ProviderSubject, in.ProviderEmail, in.ProviderEmailVerified,
	)
	return scanIdentity(row)
}

func (r *Repository) GetByProviderSubject(ctx context.Context, provider, subject string) (ExternalIdentity, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+identityColumns+` FROM external_identities WHERE provider = $1 AND provider_subject = $2`,
		provider, subject,
	)
	return scanIdentity(row)
}

func (r *Repository) GetByUserIDAndProvider(ctx context.Context, userID uuid.UUID, provider string) (ExternalIdentity, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+identityColumns+` FROM external_identities WHERE user_id = $1 AND provider = $2`,
		userID, provider,
	)
	return scanIdentity(row)
}

func (r *Repository) ListByUserID(ctx context.Context, userID uuid.UUID) ([]ExternalIdentity, error) {
	rows, err := r.db.Query(ctx, `SELECT `+identityColumns+` FROM external_identities WHERE user_id = $1`, userID)
	if err != nil {
		return nil, fmt.Errorf("list external identities: %w", err)
	}
	defer rows.Close()

	var out []ExternalIdentity
	for rows.Next() {
		identity, err := scanIdentity(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, identity)
	}
	return out, rows.Err()
}

func (r *Repository) TouchLastUsed(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE external_identities SET last_used_at = now() WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("touch external identity: %w", err)
	}
	return nil
}

func (r *Repository) DeleteByUserIDAndProvider(ctx context.Context, userID uuid.UUID, provider string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM external_identities WHERE user_id = $1 AND provider = $2`, userID, provider)
	if err != nil {
		return fmt.Errorf("delete external identity: %w", err)
	}
	return nil
}
