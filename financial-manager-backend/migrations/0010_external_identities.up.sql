-- plan.md section 11.4. One application account can link at most one
-- identity per provider, and a given provider identity belongs to exactly
-- one application account.
CREATE TABLE external_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL,
    provider_subject VARCHAR(255) NOT NULL,
    provider_email VARCHAR(320) NULL,
    provider_email_verified BOOLEAN NULL,
    linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ NULL,

    CONSTRAINT external_identities_provider_subject_unique UNIQUE (provider, provider_subject),
    CONSTRAINT external_identities_user_provider_unique UNIQUE (user_id, provider)
);
