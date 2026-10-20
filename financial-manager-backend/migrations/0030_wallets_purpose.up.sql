-- Wallet purpose (plan.md section 32.3): a short free-text note on what the
-- wallet is for ("spese quotidiane", "fondo emergenze"), used by the AI
-- analysis to judge spending against each wallet's intent. Nullable and
-- inert for every other feature; blank input is stored as NULL by the
-- service, so the CHECK only guards the length.
ALTER TABLE wallets ADD COLUMN purpose VARCHAR(280) NULL;

ALTER TABLE wallets ADD CONSTRAINT wallets_purpose_length_check
    CHECK (purpose IS NULL OR char_length(purpose) BETWEEN 1 AND 280);
