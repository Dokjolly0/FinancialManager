-- plan.md section 11.10, core subset. category_id/template_id/media_id
-- are added by later migrations once categories, transaction_templates,
-- and media_assets exist (Fase 5/6) — until then every transaction has
-- none of those, which is fine: OPENING_BALANCE (created here, Fase 2)
-- never needs them.
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    direction VARCHAR(8) NOT NULL,
    kind VARCHAR(32) NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    currency CHAR(3) NOT NULL,
    title VARCHAR(120) NOT NULL,
    title_normalized VARCHAR(120) NOT NULL,
    description TEXT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_by_session_id UUID NULL REFERENCES sessions(id),
    idempotency_key UUID NULL,
    metadata JSONB NOT NULL DEFAULT '{}',

    CONSTRAINT transactions_direction_check CHECK (direction IN ('CREDIT', 'DEBIT')),
    CONSTRAINT transactions_kind_check CHECK (
        kind IN ('STANDARD', 'OPENING_BALANCE', 'BALANCE_ADJUSTMENT', 'TRANSFER', 'IMPORT', 'RECURRING_GENERATED')
    )
);

CREATE UNIQUE INDEX transactions_user_idempotency_key_idx
    ON transactions (user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

CREATE INDEX transactions_user_occurred_idx
    ON transactions (user_id, occurred_at DESC, id DESC) WHERE deleted_at IS NULL;

CREATE INDEX transactions_wallet_occurred_idx
    ON transactions (wallet_id, occurred_at) WHERE deleted_at IS NULL;

-- Exactly one OPENING_BALANCE transaction per wallet (plan.md section 11.10).
CREATE UNIQUE INDEX transactions_one_opening_balance_per_wallet_idx
    ON transactions (wallet_id) WHERE kind = 'OPENING_BALANCE' AND deleted_at IS NULL;
