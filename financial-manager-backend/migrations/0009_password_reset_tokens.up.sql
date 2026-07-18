-- Backs POST /v1/auth/password/forgot and /reset (plan.md section 14.1,
-- 15.5: "token monouso, hashato e con scadenza breve").
CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash BYTEA NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL
);

CREATE INDEX password_reset_tokens_user_idx ON password_reset_tokens (user_id) WHERE used_at IS NULL;
