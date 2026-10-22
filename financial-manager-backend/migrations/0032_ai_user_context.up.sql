-- Personal context for the AI analysis (plan.md section 32.3): what the
-- user wants the model to know when judging their finances. Every field is
-- optional; blank text is stored as NULL by the service.
CREATE TABLE ai_user_context (
    user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    household_size SMALLINT NULL,
    income_type    VARCHAR(24) NULL,
    about_me       TEXT NULL,
    goals          TEXT NULL,
    ignore_notes   TEXT NULL,
    response_style VARCHAR(16) NULL,
    version        BIGINT NOT NULL DEFAULT 1,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ai_user_context_household_check CHECK (household_size IS NULL OR household_size BETWEEN 1 AND 20),
    CONSTRAINT ai_user_context_income_type_check CHECK (income_type IS NULL OR income_type IN
        ('EMPLOYEE', 'SELF_EMPLOYED', 'STUDENT', 'RETIRED', 'UNEMPLOYED', 'MIXED', 'OTHER')),
    CONSTRAINT ai_user_context_text_length_check CHECK (
        (about_me IS NULL OR char_length(about_me) <= 2000)
        AND (goals IS NULL OR char_length(goals) <= 2000)
        AND (ignore_notes IS NULL OR char_length(ignore_notes) <= 2000)),
    CONSTRAINT ai_user_context_response_style_check CHECK (response_style IS NULL OR response_style IN ('CONCISE', 'DETAILED'))
);
