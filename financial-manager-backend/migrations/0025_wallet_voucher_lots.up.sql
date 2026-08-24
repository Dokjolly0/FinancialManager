-- A "lot" is a batch of meal vouchers loaded onto a MEAL_VOUCHER wallet in
-- one operation (initial quantity at wallet creation, or a later
-- voucher-credit), all sharing one expires_at computed at load time from
-- the wallet's voucher_expiry_* policy (internal/wallets ComputeLotExpiry).
-- Spending/removing vouchers consumes lots FIFO by expires_at, tracked in
-- wallet_voucher_lot_consumptions (migration 0026) so a later edit/delete
-- can find and reverse exactly what a given transaction consumed.
--
-- quantity_remaining decreases both from consumption (recorded in the
-- consumptions table) and from expiry sweep (internal/transactions
-- applyVoucherLotExpiry, no consumption row — it's a loss, not a spend).
-- When a lot expires unused, quantity_expired/expired_by_transaction_id
-- record how many were lost and which system-generated "Buoni scaduti"
-- transaction wrote it off, so the lot remains visible as expiry history
-- after quantity_remaining hits 0.
CREATE TABLE wallet_voucher_lots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    quantity_total INT NOT NULL CHECK (quantity_total > 0),
    quantity_remaining INT NOT NULL CHECK (quantity_remaining >= 0 AND quantity_remaining <= quantity_total),
    quantity_expired INT NOT NULL DEFAULT 0 CHECK (quantity_expired >= 0 AND quantity_expired <= quantity_total),
    expires_at DATE NOT NULL,
    created_by_transaction_id UUID NOT NULL REFERENCES transactions(id),
    expired_by_transaction_id UUID NULL REFERENCES transactions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX wallet_voucher_lots_wallet_expiry_idx
    ON wallet_voucher_lots (wallet_id, expires_at)
    WHERE quantity_remaining > 0;

CREATE INDEX wallet_voucher_lots_created_by_idx ON wallet_voucher_lots (created_by_transaction_id);
