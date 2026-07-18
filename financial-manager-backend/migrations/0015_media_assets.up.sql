-- plan.md section 11.8. Metadata only — the actual bytes live in object
-- storage (internal/platform/storage), keyed by object_key.
CREATE TABLE media_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind VARCHAR(24) NOT NULL,
    source VARCHAR(24) NOT NULL,
    source_provider VARCHAR(40) NULL,
    source_external_id VARCHAR(255) NULL,
    source_attribution TEXT NULL,
    object_key TEXT NOT NULL UNIQUE,
    original_filename TEXT NULL,
    mime_type VARCHAR(80) NOT NULL,
    width INT NOT NULL,
    height INT NOT NULL,
    size_bytes BIGINT NOT NULL,
    sha256 BYTEA NOT NULL,
    status VARCHAR(24) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT media_assets_kind_check CHECK (kind IN ('profile', 'transaction', 'category')),
    CONSTRAINT media_assets_source_check CHECK (source IN ('upload', 'search', 'generated-import')),
    CONSTRAINT media_assets_status_check CHECK (status IN ('processing', 'ready', 'rejected', 'deleted'))
);

-- plan.md section 16.6: deduplicate per user by content hash. Reusing an
-- existing row (via ON CONFLICT DO UPDATE last_used_at) means an identical
-- re-upload never creates a second object in storage.
CREATE UNIQUE INDEX media_assets_owner_sha256_idx
    ON media_assets (owner_user_id, sha256) WHERE deleted_at IS NULL;

-- plan.md section 11.13: "Recenti" tab ordering.
CREATE INDEX media_assets_owner_last_used_idx
    ON media_assets (owner_user_id, last_used_at DESC) WHERE deleted_at IS NULL;

CREATE INDEX media_assets_owner_created_idx
    ON media_assets (owner_user_id, created_at DESC) WHERE deleted_at IS NULL;
