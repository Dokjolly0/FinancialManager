-- Multi-wallet support, part 2: wallets gain a type (drives default
-- behavior, e.g. CASH enables the denomination breakdown in migration
-- 0022) and user-facing icon/color, matching the categories.color
-- precedent (0012_categories) but NOT NULL since a wallet's icon/color is
-- always shown in the UI, never merely inert storage.
--
-- icon is a string key into a fixed in-app icon set (Flutter-side lookup
-- table), not a media asset reference — kept simple and offline, unlike
-- categories.icon_media_id.
ALTER TABLE wallets
    ADD COLUMN type VARCHAR(16) NOT NULL DEFAULT 'OTHER',
    ADD COLUMN icon VARCHAR(32) NOT NULL DEFAULT 'wallet',
    ADD COLUMN color CHAR(7) NOT NULL DEFAULT '#6750A4';

ALTER TABLE wallets ADD CONSTRAINT wallets_type_check CHECK (type IN ('CASH', 'BANK', 'OTHER'));
