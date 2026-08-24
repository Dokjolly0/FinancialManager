ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_expiry_day_check;
ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_expiry_month_check;
ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_expiry_cutoff_month_check;
ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_unit_value_check;
ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_fields_paired_check;
ALTER TABLE wallets DROP CONSTRAINT wallets_voucher_type_check;

ALTER TABLE wallets DROP CONSTRAINT wallets_type_check;
ALTER TABLE wallets ADD CONSTRAINT wallets_type_check CHECK (type IN ('CASH', 'BANK', 'OTHER'));

ALTER TABLE wallets
    DROP COLUMN voucher_unit_value_minor,
    DROP COLUMN voucher_expiry_cutoff_month,
    DROP COLUMN voucher_expiry_month,
    DROP COLUMN voucher_expiry_day;
