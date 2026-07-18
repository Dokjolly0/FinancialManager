// Package idempotency implements the claim-then-fill pattern backing
// Idempotency-Key support (plan.md sections 10.7, 11.12): a retried
// mutating request replays the first response instead of repeating the
// side effect (e.g. section 26.1: "Retry della registrazione non duplica
// il saldo iniziale").
//
// Usage: within the same DB transaction that performs the mutation,
// Claim first — if it reports an existing record, skip the mutation and
// return that record's response; otherwise perform the mutation and call
// Fill with the real response before committing.
package idempotency

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/database"
)

var ErrKeyReusedWithDifferentPayload = errors.New("idempotency key reused with a different request payload")

type Record struct {
	ResponseStatus int
	ResponseBody   []byte
}

type Store struct {
	db database.Querier
}

func NewStore(db database.Querier) *Store {
	return &Store{db: db}
}

// Claim attempts to reserve (scope, endpoint, key). If it was already
// claimed by an earlier request with the same requestHash, it returns that
// record's (possibly still-empty, if the original is in flight) response
// and claimed=false. If claimed by an earlier request with a *different*
// requestHash, it returns ErrKeyReusedWithDifferentPayload.
func (s *Store) Claim(ctx context.Context, scope, endpoint string, key uuid.UUID, requestHash []byte, ttl time.Duration) (claimed bool, existing *Record, err error) {
	var scanned string
	insertErr := s.db.QueryRow(ctx, `
		INSERT INTO idempotency_records (scope, endpoint, key, request_hash, response_status, response_body, expires_at)
		VALUES ($1, $2, $3, $4, 0, '{}', now() + $5::interval)
		ON CONFLICT (scope, endpoint, key) DO NOTHING
		RETURNING scope
	`, scope, endpoint, key, requestHash, fmt.Sprintf("%d seconds", int(ttl.Seconds()))).Scan(&scanned)

	if insertErr == nil {
		return true, nil, nil
	}
	if !errors.Is(insertErr, pgx.ErrNoRows) {
		return false, nil, fmt.Errorf("claim idempotency key: %w", insertErr)
	}

	// Already claimed by a prior request: fetch it.
	var storedHash []byte
	var status int
	var body []byte
	err = s.db.QueryRow(ctx, `
		SELECT request_hash, response_status, response_body
		FROM idempotency_records
		WHERE scope = $1 AND endpoint = $2 AND key = $3
	`, scope, endpoint, key).Scan(&storedHash, &status, &body)
	if err != nil {
		return false, nil, fmt.Errorf("fetch existing idempotency record: %w", err)
	}

	if !bytes.Equal(storedHash, requestHash) {
		return false, nil, ErrKeyReusedWithDifferentPayload
	}

	return false, &Record{ResponseStatus: status, ResponseBody: body}, nil
}

// Fill stores the real response for a previously claimed key.
func (s *Store) Fill(ctx context.Context, scope, endpoint string, key uuid.UUID, status int, body []byte) error {
	_, err := s.db.Exec(ctx, `
		UPDATE idempotency_records SET response_status = $1, response_body = $2
		WHERE scope = $3 AND endpoint = $4 AND key = $5
	`, status, body, scope, endpoint, key)
	if err != nil {
		return fmt.Errorf("fill idempotency record: %w", err)
	}
	return nil
}
