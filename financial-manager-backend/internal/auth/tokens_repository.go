package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrTokenNotFound = errors.New("token not found or already used")

// EmailVerificationTokenRepository and PasswordResetTokenRepository are
// nearly identical single-use-token stores; kept as separate types (rather
// than one generic table) so their lifetimes and security properties can
// diverge later without a migration (plan.md sections 14.1, 15.5).

type EmailVerificationTokenRepository struct{ db database.Querier }

func NewEmailVerificationTokenRepository(db database.Querier) *EmailVerificationTokenRepository {
	return &EmailVerificationTokenRepository{db: db}
}

func (r *EmailVerificationTokenRepository) WithQuerier(q database.Querier) *EmailVerificationTokenRepository {
	return &EmailVerificationTokenRepository{db: q}
}

func (r *EmailVerificationTokenRepository) Create(ctx context.Context, userID uuid.UUID, tokenHash []byte, ttl time.Duration) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO email_verification_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, now() + $3::interval)
	`, userID, tokenHash, fmt.Sprintf("%d seconds", int(ttl.Seconds())))
	if err != nil {
		return fmt.Errorf("create email verification token: %w", err)
	}
	return nil
}

// ConsumeValid marks the token used and returns its owning user ID, only
// if it exists, is unused, and is not expired. Returns ErrTokenNotFound
// otherwise — the caller cannot distinguish "wrong token" from "expired"
// from the response, which is intentional (avoid enumeration/timing hints).
func (r *EmailVerificationTokenRepository) ConsumeValid(ctx context.Context, tokenHash []byte) (uuid.UUID, error) {
	var userID uuid.UUID
	err := r.db.QueryRow(ctx, `
		UPDATE email_verification_tokens SET used_at = now()
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
		RETURNING user_id
	`, tokenHash).Scan(&userID)

	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrTokenNotFound
	}
	if err != nil {
		return uuid.Nil, fmt.Errorf("consume email verification token: %w", err)
	}
	return userID, nil
}

type PasswordResetTokenRepository struct{ db database.Querier }

func NewPasswordResetTokenRepository(db database.Querier) *PasswordResetTokenRepository {
	return &PasswordResetTokenRepository{db: db}
}

func (r *PasswordResetTokenRepository) WithQuerier(q database.Querier) *PasswordResetTokenRepository {
	return &PasswordResetTokenRepository{db: q}
}

func (r *PasswordResetTokenRepository) Create(ctx context.Context, userID uuid.UUID, tokenHash []byte, ttl time.Duration) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, now() + $3::interval)
	`, userID, tokenHash, fmt.Sprintf("%d seconds", int(ttl.Seconds())))
	if err != nil {
		return fmt.Errorf("create password reset token: %w", err)
	}
	return nil
}

func (r *PasswordResetTokenRepository) ConsumeValid(ctx context.Context, tokenHash []byte) (uuid.UUID, error) {
	var userID uuid.UUID
	err := r.db.QueryRow(ctx, `
		UPDATE password_reset_tokens SET used_at = now()
		WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now()
		RETURNING user_id
	`, tokenHash).Scan(&userID)

	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.Nil, ErrTokenNotFound
	}
	if err != nil {
		return uuid.Nil, fmt.Errorf("consume password reset token: %w", err)
	}
	return userID, nil
}
