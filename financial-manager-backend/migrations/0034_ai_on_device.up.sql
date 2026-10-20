-- On-device AI analysis (plan.md section 33): the model runs on the
-- user's phone, the server only builds the prompt and keeps the history.
--
-- ai_settings.mode picks the path the app offers (cloud provider or the
-- phone); local_model is the label of the model chosen on the phone, kept
-- server-side so every device shows the same setup. The on-device
-- disclosure is lighter than the cloud one (no third party) and has its
-- own version.
ALTER TABLE ai_settings
    ADD COLUMN mode VARCHAR(16) NOT NULL DEFAULT 'cloud',
    ADD COLUMN local_model VARCHAR(200) NULL,
    ADD COLUMN local_consent_version INT NULL,
    ADD COLUMN local_consent_accepted_at TIMESTAMPTZ NULL,
    ADD CONSTRAINT ai_settings_mode_check CHECK (mode IN ('cloud', 'on_device')),
    ADD CONSTRAINT ai_settings_local_consent_check
        CHECK ((local_consent_version IS NULL) = (local_consent_accepted_at IS NULL));

-- runtime records how an on-device analysis ran (engine, model,
-- quantization, backend, context); NULL for cloud analyses.
ALTER TABLE ai_analyses
    ADD COLUMN runtime JSONB NULL,
    ADD CONSTRAINT ai_analyses_provider_check
        CHECK (provider IN ('anthropic', 'openai', 'gemini', 'openai_compatible', 'on_device'));

-- How long the phone took to write a message (on-device only).
ALTER TABLE ai_messages ADD COLUMN duration_ms INT NULL;
