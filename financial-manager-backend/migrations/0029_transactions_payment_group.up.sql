-- Groups two or more STANDARD transaction rows that a user has explicitly
-- linked as installments of the same logical expense (e.g. an acconto/
-- deposit followed by a saldo/final payment) — plan.md's "transazioni
-- linkate" feature. Unlike transfer_pair_id (migration 0023) and
-- linked_transaction_id (migration 0027), this is NOT a pointer to one
-- specific sibling row: it's a shared, arbitrary group key generated at
-- the moment two transactions are first linked, so there is no single row
-- for it to REFERENCE. It also has no accounting effect whatsoever — every
-- member keeps counting individually in reports/totals; the group exists
-- purely so the UI can show "these N payments belong together" and their
-- combined total. Membership is enforced at the application layer
-- (transactions.Service): a group is created/extended/dissolved as members
-- are linked/deleted, with no DB-level "at least 2 members" constraint,
-- since a plain shared-key column can't express that.
ALTER TABLE transactions ADD COLUMN payment_group_id UUID NULL;

CREATE INDEX transactions_payment_group_idx
    ON transactions (payment_group_id)
    WHERE payment_group_id IS NOT NULL;
