-- Generic self-link between two transaction rows produced by one logical
-- operation, used by voucher-pasto expenses that are paid partly with
-- vouchers and partly from another wallet: the voucher-wallet DEBIT leg and
-- the other-wallet DEBIT leg for the shortfall point at each other. Both
-- rows are inserted in the same DB transaction with pre-generated UUIDs,
-- same pattern as transactions.transfer_pair_id (migration 0023) — kept as
-- a separate column rather than reusing transfer_pair_id because these legs
-- are kind=STANDARD (so they count in reports, unlike TRANSFER legs which
-- are intentionally excluded), not a wallet-to-wallet transfer.
ALTER TABLE transactions ADD COLUMN linked_transaction_id UUID NULL REFERENCES transactions(id);

CREATE INDEX transactions_linked_transaction_idx
    ON transactions (linked_transaction_id)
    WHERE linked_transaction_id IS NOT NULL;
