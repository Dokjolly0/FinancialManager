-- plan.md section 11.9. default_media_id has no FK yet (media_assets lands
-- in Fase 6); default_category_id references the categories table added in
-- the previous migration.
CREATE TABLE transaction_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    direction VARCHAR(8) NOT NULL,
    title VARCHAR(120) NOT NULL,
    title_normalized VARCHAR(120) NOT NULL,
    default_category_id UUID NULL REFERENCES categories(id),
    default_media_id UUID NULL,
    default_description TEXT NULL,
    usage_count BIGINT NOT NULL DEFAULT 0,
    last_used_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived_at TIMESTAMPTZ NULL,

    CONSTRAINT transaction_templates_direction_check CHECK (direction IN ('CREDIT', 'DEBIT'))
);

CREATE UNIQUE INDEX transaction_templates_user_direction_title_idx
    ON transaction_templates (user_id, direction, title_normalized)
    WHERE archived_at IS NULL;

-- plan.md section 11.13: autocomplete ordered by frequency and recency.
CREATE INDEX transaction_templates_user_direction_usage_idx
    ON transaction_templates (user_id, direction, last_used_at DESC)
    WHERE archived_at IS NULL;
