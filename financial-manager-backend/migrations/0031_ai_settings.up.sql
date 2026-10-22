-- AI analysis settings (plan.md section 32.3).
--
-- ai_provider_credentials keeps one row per (user, provider, base_url), so
-- switching provider and back does not mean typing the API key again; each
-- row also remembers the model last chosen for it. base_url is '' for the
-- native providers (fixed endpoints) and required for openai_compatible.
-- The API key is stored only encrypted (internal/platform/secretbox,
-- AES-256-GCM bound to user, provider and base_url); api_key_hint is the
-- masked form shown back to the user ("sk-…a1b2"). The key is nullable
-- because a local OpenAI-compatible server may need none.
CREATE TABLE ai_provider_credentials (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider          VARCHAR(32) NOT NULL,
    base_url          TEXT NOT NULL DEFAULT '',
    api_key_encrypted BYTEA NULL,
    api_key_hint      VARCHAR(16) NULL,
    model             VARCHAR(200) NULL,
    last_tested_at    TIMESTAMPTZ NULL,
    last_test_ok      BOOLEAN NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_provider_credentials_provider_check
        CHECK (provider IN ('anthropic', 'openai', 'gemini', 'openai_compatible')),
    CONSTRAINT ai_provider_credentials_base_url_check
        CHECK ((provider = 'openai_compatible') = (base_url <> '')),
    CONSTRAINT ai_provider_credentials_key_hint_check
        CHECK ((api_key_encrypted IS NULL) = (api_key_hint IS NULL)),
    CONSTRAINT ai_provider_credentials_unique UNIQUE (user_id, provider, base_url)
);

-- ai_settings is one row per user, created on first save. consent_version
-- records which version of the disclosure (ai.ConsentVersion) the user
-- accepted; an older value means consent must be asked again.
CREATE TABLE ai_settings (
    user_id                      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    active_credential_id         UUID NULL REFERENCES ai_provider_credentials(id) ON DELETE SET NULL,
    consent_version              INT NULL,
    consent_accepted_at          TIMESTAMPTZ NULL,
    max_output_tokens            INT NOT NULL DEFAULT 4096,
    input_price_per_mtok         NUMERIC(12, 4) NULL,
    output_price_per_mtok        NUMERIC(12, 4) NULL,
    default_include_transactions BOOLEAN NOT NULL DEFAULT false,
    default_anonymize_titles     BOOLEAN NOT NULL DEFAULT false,
    version                      BIGINT NOT NULL DEFAULT 1,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_settings_max_output_tokens_check CHECK (max_output_tokens BETWEEN 256 AND 32000),
    CONSTRAINT ai_settings_prices_check
        CHECK ((input_price_per_mtok IS NULL OR input_price_per_mtok >= 0)
           AND (output_price_per_mtok IS NULL OR output_price_per_mtok >= 0)),
    CONSTRAINT ai_settings_consent_check CHECK ((consent_version IS NULL) = (consent_accepted_at IS NULL))
);
