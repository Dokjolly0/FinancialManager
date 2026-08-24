-- Join table recording exactly how many vouchers a given transaction
-- (voucher-expense DEBIT leg, or a manual voucher-removal) consumed from
-- each lot it touched. Without this, editing or deleting that transaction
-- could not know which lot(s) to credit back — a FIFO consumption can span
-- multiple lots, and other consumptions may have happened on the same lots
-- since.
CREATE TABLE wallet_voucher_lot_consumptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    lot_id UUID NOT NULL REFERENCES wallet_voucher_lots(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX wallet_voucher_lot_consumptions_transaction_idx
    ON wallet_voucher_lot_consumptions (transaction_id);
CREATE INDEX wallet_voucher_lot_consumptions_lot_idx
    ON wallet_voucher_lot_consumptions (lot_id);
