package users

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrNotFound = errors.New("user not found")

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

// WithQuerier returns a repository bound to a different Querier (typically
// a pgx.Tx), so the same methods work inside a larger transaction.
func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

const userColumns = `
	id, first_name, last_name, username, username_normalized,
	email, email_normalized, email_verified_at,
	avatar_mode, avatar_media_id, avatar_background_color, avatar_text_color,
	locale, timezone, theme, balance_hidden_default, first_day_of_week, status,
	created_at, updated_at, deleted_at, version
`

func scanUser(row pgx.Row) (User, error) {
	var u User
	err := row.Scan(
		&u.ID, &u.FirstName, &u.LastName, &u.Username, &u.UsernameNormalized,
		&u.Email, &u.EmailNormalized, &u.EmailVerifiedAt,
		&u.AvatarMode, &u.AvatarMediaID, &u.AvatarBackgroundColor, &u.AvatarTextColor,
		&u.Locale, &u.Timezone, &u.Theme, &u.BalanceHiddenDefault, &u.FirstDayOfWeek, &u.Status,
		&u.CreatedAt, &u.UpdatedAt, &u.DeletedAt, &u.Version,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, ErrNotFound
	}
	if err != nil {
		return User{}, fmt.Errorf("scan user: %w", err)
	}
	return u, nil
}

type CreateInput struct {
	FirstName             string
	LastName              string
	Username              string
	Email                 string
	AvatarBackgroundColor string
	AvatarTextColor       string
	Locale                string
	Timezone              string
}

func (r *Repository) Create(ctx context.Context, in CreateInput) (User, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO users (
			first_name, last_name, username, username_normalized,
			email, email_normalized,
			avatar_mode, avatar_background_color, avatar_text_color,
			locale, timezone
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING `+userColumns,
		in.FirstName, in.LastName, in.Username, NormalizeUsername(in.Username),
		in.Email, NormalizeEmail(in.Email),
		AvatarModeGenerated, in.AvatarBackgroundColor, in.AvatarTextColor,
		in.Locale, in.Timezone,
	)
	return scanUser(row)
}

func (r *Repository) GetByID(ctx context.Context, id uuid.UUID) (User, error) {
	row := r.db.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE id = $1 AND deleted_at IS NULL`, id)
	return scanUser(row)
}

func (r *Repository) GetByUsernameNormalized(ctx context.Context, usernameNormalized string) (User, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+userColumns+` FROM users WHERE username_normalized = $1 AND deleted_at IS NULL`,
		usernameNormalized,
	)
	return scanUser(row)
}

func (r *Repository) GetByEmailNormalized(ctx context.Context, emailNormalized string) (User, error) {
	row := r.db.QueryRow(ctx,
		`SELECT `+userColumns+` FROM users WHERE email_normalized = $1 AND deleted_at IS NULL`,
		emailNormalized,
	)
	return scanUser(row)
}

// UsernameOrEmailTaken reports whether the normalized username or email is
// already in use, so registration can return a precise field error before
// attempting the insert (which would otherwise fail on a unique
// constraint without saying which field).
func (r *Repository) UsernameOrEmailTaken(ctx context.Context, usernameNormalized, emailNormalized string) (usernameTaken, emailTaken bool, err error) {
	row := r.db.QueryRow(ctx, `
		SELECT
			EXISTS(SELECT 1 FROM users WHERE username_normalized = $1 AND deleted_at IS NULL),
			EXISTS(SELECT 1 FROM users WHERE email_normalized = $2 AND deleted_at IS NULL)
	`, usernameNormalized, emailNormalized)

	if err := row.Scan(&usernameTaken, &emailTaken); err != nil {
		return false, false, fmt.Errorf("check username/email availability: %w", err)
	}
	return usernameTaken, emailTaken, nil
}

func (r *Repository) MarkEmailVerified(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE users SET email_verified_at = now(), updated_at = now() WHERE id = $1`, userID)
	if err != nil {
		return fmt.Errorf("mark email verified: %w", err)
	}
	return nil
}

type UpdateProfileFields struct {
	FirstName            string
	LastName             string
	Timezone             string
	Locale               string
	Theme                string
	BalanceHiddenDefault bool
	FirstDayOfWeek       string
}

func (r *Repository) UpdateProfile(ctx context.Context, userID uuid.UUID, expectedVersion int64, in UpdateProfileFields) (User, error) {
	row := r.db.QueryRow(ctx, `
		UPDATE users SET
			first_name = $1, last_name = $2, timezone = $3, locale = $4, theme = $5,
			balance_hidden_default = $6, first_day_of_week = $7,
			updated_at = now(), version = version + 1
		WHERE id = $8 AND version = $9 AND deleted_at IS NULL
		RETURNING `+userColumns,
		in.FirstName, in.LastName, in.Timezone, in.Locale, in.Theme,
		in.BalanceHiddenDefault, in.FirstDayOfWeek,
		userID, expectedVersion,
	)
	return scanUser(row)
}
