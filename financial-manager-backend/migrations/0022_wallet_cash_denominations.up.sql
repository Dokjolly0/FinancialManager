-- Cash denomination breakdown for CASH-type wallets ("count the cash you
-- physically hold"). Purely informational: it is never used to derive or
-- constrain wallets.current_balance_minor, so it doesn't need to live
-- inside the balance-mutation transaction machinery (plan.md section 13).
--
-- One row per (wallet, denomination). enabled lets a user hide a
-- denomination they don't want to bother tracking (e.g. 1-2 cent coins)
-- without losing whatever count was last saved for it. Rows are only
-- written when the editor screen saves — a wallet with no rows here simply
-- means "never customized," and the API layer fills in the full fixed set
-- with count=0/enabled=true defaults for any missing value.
CREATE TABLE wallet_cash_denominations (
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    denomination_minor INT NOT NULL,
    count INT NOT NULL DEFAULT 0 CHECK (count >= 0),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (wallet_id, denomination_minor),
    CONSTRAINT wallet_cash_denominations_value_check CHECK (
        denomination_minor IN (
            50000, 20000, 10000, 5000, 2000, 1000, 500, -- EUR 500/200/100/50/20/10/5 notes
            200, 100, 50, 20, 10, 5, 2, 1                -- EUR 2/1/0.50/0.20/0.10/0.05/0.02/0.01 coins
        )
    )
);
