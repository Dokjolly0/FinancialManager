-- plan.md section 11.3. failed_attempts/locked_until back a persistent
-- lockout that does not depend solely on Redis (Redis rate limiting is an
-- additional, faster-reacting layer on top).
CREATE TABLE password_credentials (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash TEXT NOT NULL,
    password_algorithm VARCHAR(32) NOT NULL DEFAULT 'argon2id',
    password_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    failed_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ NULL
);
