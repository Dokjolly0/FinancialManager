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

var ErrCredentialsNotFound = errors.New("password credentials not found")

type CredentialsRepository struct {
	db database.Querier
}

func NewCredentialsRepository(db database.Querier) *CredentialsRepository {
	return &CredentialsRepository{db: db}
}

func (r *CredentialsRepository) WithQuerier(q database.Querier) *CredentialsRepository {
	return &CredentialsRepository{db: q}
}

func (r *CredentialsRepository) Create(ctx context.Context, userID uuid.UUID, passwordHash string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO password_credentials (user_id, password_hash, password_algorithm, password_updated_at)
		VALUES ($1, $2, 'argon2id', now())
	`, userID, passwordHash)
	if err != nil {
		return fmt.Errorf("insert password credentials: %w", err)
	}
	return nil
}

type Credentials struct {
	UserID         uuid.UUID
	PasswordHash   string
	FailedAttempts int
	LockedUntil    *time.Time
}

func (r *CredentialsRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (Credentials, error) {
	var c Credentials
	err := r.db.QueryRow(ctx, `
		SELECT user_id, password_hash, failed_attempts, locked_until
		FROM password_credentials WHERE user_id = $1
	`, userID).Scan(&c.UserID, &c.PasswordHash, &c.FailedAttempts, &c.LockedUntil)

	if errors.Is(err, pgx.ErrNoRows) {
		return Credentials{}, ErrCredentialsNotFound
	}
	if err != nil {
		return Credentials{}, fmt.Errorf("get password credentials: %w", err)
	}
	return c, nil
}

func (r *CredentialsRepository) UpdatePassword(ctx context.Context, userID uuid.UUID, passwordHash string) error {
	_, err := r.db.Exec(ctx, `
		UPDATE password_credentials
		SET password_hash = $1, password_updated_at = now(), failed_attempts = 0, locked_until = NULL
		WHERE user_id = $2
	`, passwordHash, userID)
	if err != nil {
		return fmt.Errorf("update password: %w", err)
	}
	return nil
}

// RecordFailedAttempt increments the failed-attempt counter and locks the
// account for lockDuration once threshold is reached. This is the
// persistent lockout layer that does not depend solely on Redis (plan.md
// section 11.3).
func (r *CredentialsRepository) RecordFailedAttempt(ctx context.Context, userID uuid.UUID, threshold int, lockDuration time.Duration) error {
	_, err := r.db.Exec(ctx, `
		UPDATE password_credentials
		SET failed_attempts = failed_attempts + 1,
			locked_until = CASE WHEN failed_attempts + 1 >= $2 THEN now() + $3::interval ELSE locked_until END
		WHERE user_id = $1
	`, userID, threshold, fmt.Sprintf("%d seconds", int(lockDuration.Seconds())))
	if err != nil {
		return fmt.Errorf("record failed attempt: %w", err)
	}
	return nil
}

func (r *CredentialsRepository) ResetFailedAttempts(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `
		UPDATE password_credentials SET failed_attempts = 0, locked_until = NULL WHERE user_id = $1
	`, userID)
	if err != nil {
		return fmt.Errorf("reset failed attempts: %w", err)
	}
	return nil
}
