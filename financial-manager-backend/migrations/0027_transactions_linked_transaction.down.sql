DROP INDEX transactions_linked_transaction_idx;
ALTER TABLE transactions DROP COLUMN linked_transaction_id;
