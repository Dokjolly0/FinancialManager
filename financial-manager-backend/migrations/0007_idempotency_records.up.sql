-- plan.md section 11.12 / 10.7. Stores the first response for a given
-- (user, endpoint, key) so a retried mutating request (e.g. registration
-- retried after a dropped connection) replays the original result instead
-- of repeating the side effect (plan.md section 26.1: "Retry della
-- registrazione non duplica il saldo iniziale").
--
-- Registration has no authenticated user yet, so it keys idempotency by
-- normalized email instead of user_id for that one endpoint; every other
-- endpoint keys by the authenticated user_id.
CREATE TABLE idempotency_records (
    scope VARCHAR(320) NOT NULL,
    endpoint VARCHAR(160) NOT NULL,
    key UUID NOT NULL,
    request_hash BYTEA NOT NULL,
    response_status INT NOT NULL,
    response_body JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (scope, endpoint, key)
);
