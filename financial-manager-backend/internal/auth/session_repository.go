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

var ErrSessionNotFound = errors.New("session not found")

type SessionRepository struct {
	db database.Querier
}

func NewSessionRepository(db database.Querier) *SessionRepository {
	return &SessionRepository{db: db}
}

func (r *SessionRepository) WithQuerier(q database.Querier) *SessionRepository {
	return &SessionRepository{db: q}
}

const sessionColumns = `id, user_id, refresh_token_hash, device_name, platform, created_at, last_used_at, expires_at, revoked_at, replaced_by_session_id`

func scanSession(row pgx.Row) (Session, error) {
	var s Session
	err := row.Scan(&s.ID, &s.UserID, &s.RefreshTokenHash, &s.DeviceName, &s.Platform, &s.CreatedAt, &s.LastUsedAt, &s.ExpiresAt, &s.RevokedAt, &s.ReplacedBySessionID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Session{}, ErrSessionNotFound
	}
	if err != nil {
		return Session{}, fmt.Errorf("scan session: %w", err)
	}
	return s, nil
}

type CreateSessionInput struct {
	UserID           uuid.UUID
	RefreshTokenHash []byte
	DeviceName       *string
	Platform         *string
	ExpiresAt        time.Time
}

func (r *SessionRepository) Create(ctx context.Context, in CreateSessionInput) (Session, error) {
	row := r.db.QueryRow(ctx, `
		INSERT INTO sessions (user_id, refresh_token_hash, device_name, platform, expires_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING `+sessionColumns,
		in.UserID, in.RefreshTokenHash, in.DeviceName, in.Platform, in.ExpiresAt,
	)
	return scanSession(row)
}

func (r *SessionRepository) GetByRefreshTokenHash(ctx context.Context, hash []byte) (Session, error) {
	row := r.db.QueryRow(ctx, `SELECT `+sessionColumns+` FROM sessions WHERE refresh_token_hash = $1`, hash)
	return scanSession(row)
}

func (r *SessionRepository) GetByID(ctx context.Context, id uuid.UUID) (Session, error) {
	row := r.db.QueryRow(ctx, `SELECT `+sessionColumns+` FROM sessions WHERE id = $1`, id)
	return scanSession(row)
}

// Rotate marks oldSessionID revoked+replaced by the newly created session
// carrying newRefreshTokenHash, returning the new session (plan.md section
// 15.6: "rilevazione riuso token e revoca della famiglia" — reuse
// detection checks whether a presented token belongs to an
// already-rotated session).
func (r *SessionRepository) Rotate(ctx context.Context, oldSessionID uuid.UUID, in CreateSessionInput) (Session, error) {
	newSession, err := r.Create(ctx, in)
	if err != nil {
		return Session{}, err
	}

	_, err = r.db.Exec(ctx, `
		UPDATE sessions SET revoked_at = now(), replaced_by_session_id = $1 WHERE id = $2
	`, newSession.ID, oldSessionID)
	if err != nil {
		return Session{}, fmt.Errorf("revoke rotated session: %w", err)
	}

	return newSession, nil
}

func (r *SessionRepository) Revoke(ctx context.Context, sessionID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL`, sessionID)
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

func (r *SessionRepository) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, userID)
	if err != nil {
		return fmt.Errorf("revoke all sessions: %w", err)
	}
	return nil
}

func (r *SessionRepository) TouchLastUsed(ctx context.Context, sessionID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `UPDATE sessions SET last_used_at = now() WHERE id = $1`, sessionID)
	if err != nil {
		return fmt.Errorf("touch session: %w", err)
	}
	return nil
}
