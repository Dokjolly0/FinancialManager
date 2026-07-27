-- Wallet-to-wallet transfers (kind='TRANSFER', already reserved in the
-- transactions_kind_check constraint since 0006_transactions_core but
-- unused until now) are represented as two linked ledger rows: one DEBIT
-- on the source wallet and one CREDIT on the destination wallet, each
-- pointing at the other via transfer_pair_id. Both rows are inserted in
-- the same DB transaction with pre-generated UUIDs, so this column is
-- always set together with the row itself, never backfilled after the fact.
ALTER TABLE transactions ADD COLUMN transfer_pair_id UUID NULL REFERENCES transactions(id);

CREATE INDEX transactions_transfer_pair_idx ON transactions (transfer_pair_id) WHERE transfer_pair_id IS NOT NULL;
