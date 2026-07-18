package transactions

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/database"
)

const (
	AuditActionCreated = "created"
	AuditActionUpdated = "updated"
	AuditActionDeleted = "deleted"
)

type AuditRepository struct {
	db database.Querier
}

func NewAuditRepository(db database.Querier) *AuditRepository {
	return &AuditRepository{db: db}
}

func (r *AuditRepository) WithQuerier(q database.Querier) *AuditRepository {
	return &AuditRepository{db: q}
}

// Record writes one audit row. before/after are marshaled as-is; pass nil
// for whichever side doesn't apply (e.g. before is nil on create).
func (r *AuditRepository) Record(ctx context.Context, transactionID, userID uuid.UUID, action string, before, after any) error {
	var beforeJSON, afterJSON []byte
	var err error
	if before != nil {
		if beforeJSON, err = json.Marshal(before); err != nil {
			return fmt.Errorf("marshal audit before data: %w", err)
		}
	}
	if after != nil {
		if afterJSON, err = json.Marshal(after); err != nil {
			return fmt.Errorf("marshal audit after data: %w", err)
		}
	}

	_, err = r.db.Exec(ctx, `
		INSERT INTO transaction_audit_events (transaction_id, user_id, action, before_data, after_data)
		VALUES ($1, $2, $3, $4, $5)
	`, transactionID, userID, action, beforeJSON, afterJSON)
	if err != nil {
		return fmt.Errorf("insert audit event: %w", err)
	}
	return nil
}
