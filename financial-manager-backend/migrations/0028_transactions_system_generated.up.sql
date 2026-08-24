-- Marks a transaction as written by the backend itself rather than by user
-- action — today only the "Buoni scaduti" BALANCE_ADJUSTMENT rows created
-- by applyVoucherLotExpiry (internal/transactions) when meal-voucher lots
-- expire unused. System-generated rows are never editable/deletable by the
-- user: the expiry is a real, already-realized loss, not a correction.
ALTER TABLE transactions ADD COLUMN system_generated BOOLEAN NOT NULL DEFAULT FALSE;
