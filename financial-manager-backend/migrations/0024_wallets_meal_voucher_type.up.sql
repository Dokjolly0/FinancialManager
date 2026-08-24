-- Fourth wallet type: MEAL_VOUCHER (buoni pasto). Unlike CASH/BANK/OTHER,
-- a meal-voucher wallet's balance is not a free-form amount: it is always
-- N * voucher_unit_value_minor for whole vouchers held across active lots
-- (wallet_voucher_lots, migration 0025), so the unit value and the expiry
-- policy used to compute each new lot's expires_at both live on the wallet
-- row itself. voucher_unit_value_minor is immutable once set (enforced in
-- internal/wallets service, not here) — changing the face value means
-- creating a new wallet. The three expiry_* columns ARE editable later;
-- changing them only affects lots created afterwards.
--
-- All four voucher_* columns are set together, iff type = 'MEAL_VOUCHER' —
-- enforced with paired NULL-ness CHECKs rather than one column so each can
-- carry its own range constraint.
ALTER TABLE wallets
    ADD COLUMN voucher_unit_value_minor INT NULL,
    ADD COLUMN voucher_expiry_cutoff_month INT NULL,
    ADD COLUMN voucher_expiry_month INT NULL,
    ADD COLUMN voucher_expiry_day INT NULL;

ALTER TABLE wallets DROP CONSTRAINT wallets_type_check;
ALTER TABLE wallets ADD CONSTRAINT wallets_type_check CHECK (type IN ('CASH', 'BANK', 'OTHER', 'MEAL_VOUCHER'));

ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_type_check
    CHECK ((type = 'MEAL_VOUCHER') = (voucher_unit_value_minor IS NOT NULL));
ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_fields_paired_check
    CHECK (
        (voucher_unit_value_minor IS NOT NULL) = (voucher_expiry_cutoff_month IS NOT NULL)
        AND (voucher_unit_value_minor IS NOT NULL) = (voucher_expiry_month IS NOT NULL)
        AND (voucher_unit_value_minor IS NOT NULL) = (voucher_expiry_day IS NOT NULL)
    );
ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_unit_value_check
    CHECK (voucher_unit_value_minor IS NULL OR voucher_unit_value_minor > 0);
ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_expiry_cutoff_month_check
    CHECK (voucher_expiry_cutoff_month IS NULL OR voucher_expiry_cutoff_month BETWEEN 1 AND 12);
ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_expiry_month_check
    CHECK (voucher_expiry_month IS NULL OR voucher_expiry_month BETWEEN 1 AND 12);
ALTER TABLE wallets ADD CONSTRAINT wallets_voucher_expiry_day_check
    CHECK (voucher_expiry_day IS NULL OR voucher_expiry_day BETWEEN 1 AND 31);
