-- Backs POST /v1/auth/email/verify and /resend-verification (plan.md
-- section 14.1). Only the token hash is stored (section 15.5 pattern
-- applied to every single-use token, not just password reset).
CREATE TABLE email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash BYTEA NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL
);

CREATE INDEX email_verification_tokens_user_idx ON email_verification_tokens (user_id) WHERE used_at IS NULL;
