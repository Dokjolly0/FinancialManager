-- plan.md section 11.2. avatar_media_id has no FK yet: media_assets is
-- introduced in a later migration (Fase 6); custom avatar upload is not
-- wired until then, so the column stays unreferenced but present.
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    username VARCHAR(40) NOT NULL,
    username_normalized VARCHAR(40) NOT NULL UNIQUE,
    email VARCHAR(320) NOT NULL,
    email_normalized VARCHAR(320) NOT NULL UNIQUE,
    email_verified_at TIMESTAMPTZ NULL,
    avatar_mode VARCHAR(20) NOT NULL DEFAULT 'generated',
    avatar_media_id UUID NULL,
    avatar_background_color CHAR(7) NOT NULL,
    avatar_text_color CHAR(7) NOT NULL,
    locale VARCHAR(16) NOT NULL DEFAULT 'it-IT',
    timezone VARCHAR(64) NOT NULL DEFAULT 'Europe/Rome',
    theme VARCHAR(16) NOT NULL DEFAULT 'system',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ NULL,
    version BIGINT NOT NULL DEFAULT 1,

    CONSTRAINT users_avatar_mode_check CHECK (avatar_mode IN ('generated', 'custom')),
    CONSTRAINT users_avatar_background_color_format CHECK (avatar_background_color ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT users_avatar_text_color_format CHECK (avatar_text_color ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT users_avatar_custom_requires_media CHECK (avatar_mode <> 'custom' OR avatar_media_id IS NOT NULL),
    CONSTRAINT users_theme_check CHECK (theme IN ('system', 'light', 'dark')),
    CONSTRAINT users_status_check CHECK (status IN ('active', 'pending_deletion', 'deleted'))
);
