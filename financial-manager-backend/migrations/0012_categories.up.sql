-- plan.md section 11.7. owner_user_id NULL marks a system category, shared
-- by every user; icon_media_id has no FK yet since media_assets doesn't
-- exist until Fase 6 — it stays a plain nullable UUID until then.
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(80) NOT NULL,
    name_normalized VARCHAR(80) NOT NULL,
    direction_scope VARCHAR(16) NOT NULL,
    icon_media_id UUID NULL,
    color CHAR(7) NULL,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    archived_at TIMESTAMPTZ NULL,

    CONSTRAINT categories_direction_scope_check CHECK (direction_scope IN ('DEBIT', 'CREDIT', 'BOTH'))
);

-- A user's own custom categories can't collide by name within the same
-- direction scope. System rows (owner_user_id NULL) are exempt: NULL is
-- never equal to NULL in a unique index, and their names are controlled by
-- the seed data below, not by user input.
CREATE UNIQUE INDEX categories_owner_name_scope_idx
    ON categories (owner_user_id, name_normalized, direction_scope)
    WHERE archived_at IS NULL AND owner_user_id IS NOT NULL;

CREATE INDEX categories_owner_idx ON categories (owner_user_id) WHERE archived_at IS NULL;

-- Seed categories (plan.md section 11.7 "Categorie iniziali suggerite").
INSERT INTO categories (name, name_normalized, direction_scope, is_system, sort_order) VALUES
    ('Casa', 'casa', 'DEBIT', TRUE, 0),
    ('Alimentari', 'alimentari', 'DEBIT', TRUE, 1),
    ('Ristorazione', 'ristorazione', 'DEBIT', TRUE, 2),
    ('Trasporti', 'trasporti', 'DEBIT', TRUE, 3),
    ('Carburante', 'carburante', 'DEBIT', TRUE, 4),
    ('Abbonamenti', 'abbonamenti', 'DEBIT', TRUE, 5),
    ('Salute', 'salute', 'DEBIT', TRUE, 6),
    ('Svago', 'svago', 'DEBIT', TRUE, 7),
    ('Acquisti', 'acquisti', 'DEBIT', TRUE, 8),
    ('Imposte', 'imposte', 'DEBIT', TRUE, 9),
    ('Altro', 'altro', 'DEBIT', TRUE, 10),
    ('Stipendio', 'stipendio', 'CREDIT', TRUE, 0),
    ('Rimborso', 'rimborso', 'CREDIT', TRUE, 1),
    ('Regalo', 'regalo', 'CREDIT', TRUE, 2),
    ('Vendita', 'vendita', 'CREDIT', TRUE, 3),
    ('Interessi', 'interessi', 'CREDIT', TRUE, 4),
    ('Altro', 'altro', 'CREDIT', TRUE, 5);
