-- plan.md section 11.6. current_balance_minor is a denormalized
-- projection kept in sync with the transactions ledger inside the same DB
-- transaction as every mutation (section 13). Single active wallet per
-- user in the MVP; the partial unique index leaves room for multiple
-- wallets post-MVP without a schema rewrite.
CREATE TABLE wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL DEFAULT 'Portafoglio principale',
    currency CHAR(3) NOT NULL DEFAULT 'EUR',
    current_balance_minor BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version BIGINT NOT NULL DEFAULT 1,
    archived_at TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX wallets_one_active_per_user_idx ON wallets (user_id) WHERE archived_at IS NULL;
