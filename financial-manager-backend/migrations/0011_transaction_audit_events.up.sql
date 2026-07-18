-- plan.md section 11.11. Tracks every mutation to a transaction — created
-- at Fase 2 for OPENING_BALANCE, used from Fase 4 onward for
-- create/update/delete of standard transactions and adjustments.
CREATE TABLE transaction_audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL,
    user_id UUID NOT NULL,
    action VARCHAR(24) NOT NULL,
    before_data JSONB NULL,
    after_data JSONB NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    request_id UUID NULL,

    CONSTRAINT transaction_audit_events_action_check CHECK (action IN ('created', 'updated', 'deleted', 'restored'))
);

CREATE INDEX transaction_audit_events_transaction_idx ON transaction_audit_events (transaction_id, created_at DESC);
