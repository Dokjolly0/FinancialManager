-- plan.md section 14.2/20.2: POST /v1/me/export + GET /v1/me/export/{id}.
-- Generation currently runs synchronously inside the POST handler, but the
-- table already models an async job (status/object_key/error_message) so
-- it can move to the worker without an API or schema change.
CREATE TABLE export_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    format VARCHAR(10) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'processing',
    object_key TEXT NULL,
    error_message TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ NULL,

    CONSTRAINT export_records_format_check CHECK (format IN ('csv', 'json')),
    CONSTRAINT export_records_status_check CHECK (status IN ('processing', 'ready', 'failed'))
);

CREATE INDEX export_records_user_id_idx ON export_records(user_id);
