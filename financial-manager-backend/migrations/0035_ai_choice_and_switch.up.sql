-- AI features switch (plan.md section 32.10): ai_enabled hides every AI
-- entry point in the app for this account. On by default, so existing
-- users keep what they had; turning it off deletes nothing.
ALTER TABLE users ADD COLUMN ai_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- The provider account a cloud analysis ran with (plan.md section 32.4):
-- each analysis may pick any stored credential, and its follow-ups keep
-- using it. NULL for on-device analyses, older rows, or a credential since
-- removed (follow-ups then fall back to the active one).
ALTER TABLE ai_analyses
    ADD COLUMN credential_id UUID NULL REFERENCES ai_provider_credentials (id) ON DELETE SET NULL;
