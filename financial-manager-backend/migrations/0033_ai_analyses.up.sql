-- AI analyses and their conversation (plan.md section 32.3).
--
-- An analysis keeps everything needed to replay it exactly: the system
-- prompt as sent (system_prompt) and, as its first message (kind CONTEXT),
-- the user message with instructions and data block. Follow-up questions
-- replay these stored messages and never recompute the data, so answers
-- stay consistent with the report even if the ledger changes afterwards.
--
-- status mirrors the REPORT message: STREAMING while the model writes,
-- then COMPLETED, FAILED or CANCELLED (client gone; partial text kept).
-- client_request_id makes a retried run idempotent (SSE responses cannot
-- go through the Idempotency-Key replay used by JSON endpoints).
CREATE TABLE ai_analyses (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title               VARCHAR(200) NOT NULL,
    preset              VARCHAR(32) NOT NULL,
    period_from         TIMESTAMPTZ NULL,
    period_to           TIMESTAMPTZ NOT NULL,
    timezone            VARCHAR(64) NOT NULL,
    wallet_ids          UUID[] NOT NULL,
    options             JSONB NOT NULL,
    provider            VARCHAR(32) NOT NULL,
    model               VARCHAR(200) NOT NULL,
    prompt_version      VARCHAR(16) NOT NULL,
    system_prompt       TEXT NOT NULL,
    data_fingerprint    CHAR(64) NOT NULL,
    status              VARCHAR(16) NOT NULL,
    error_code          VARCHAR(48) NULL,
    input_tokens_total  INT NOT NULL DEFAULT 0,
    output_tokens_total INT NOT NULL DEFAULT 0,
    client_request_id   UUID NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_analyses_preset_check CHECK (preset IN
        ('MONTHLY_CHECKUP', 'ANOMALIES', 'SAVINGS', 'RECURRING', 'WALLET_PURPOSE', 'CUSTOM')),
    CONSTRAINT ai_analyses_status_check CHECK (status IN ('STREAMING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT ai_analyses_request_unique UNIQUE (user_id, client_request_id)
);

CREATE INDEX ai_analyses_user_created_idx ON ai_analyses (user_id, created_at DESC, id DESC);

CREATE TABLE ai_messages (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id   UUID NOT NULL REFERENCES ai_analyses(id) ON DELETE CASCADE,
    seq           INT NOT NULL,
    role          VARCHAR(16) NOT NULL,
    kind          VARCHAR(16) NOT NULL,
    content       TEXT NOT NULL,
    status        VARCHAR(16) NOT NULL,
    error_code    VARCHAR(48) NULL,
    model         VARCHAR(200) NULL,
    input_tokens  INT NULL,
    output_tokens INT NULL,
    truncated     BOOLEAN NOT NULL DEFAULT false,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_messages_role_check CHECK (role IN ('user', 'assistant')),
    CONSTRAINT ai_messages_kind_check CHECK (kind IN ('CONTEXT', 'REPORT', 'QUESTION', 'ANSWER')),
    CONSTRAINT ai_messages_status_check CHECK (status IN ('STREAMING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    CONSTRAINT ai_messages_seq_unique UNIQUE (analysis_id, seq)
);
