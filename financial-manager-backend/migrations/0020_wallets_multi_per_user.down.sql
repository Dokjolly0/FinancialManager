-- Rollback will fail if any user has more than one active wallet at that
-- point — acceptable since a genuine rollback implies rolling back the
-- application code too, before real multi-wallet data accumulates.
CREATE UNIQUE INDEX wallets_one_active_per_user_idx ON wallets (user_id) WHERE archived_at IS NULL;
