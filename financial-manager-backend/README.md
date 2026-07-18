# financial-manager-backend

Go modular-monolith backend for FinancialManager (see `/plan.md` at the repo root for the full product and architecture specification).

## Stack

- Go, `chi` router, `pgx` (PostgreSQL), `go-redis` (Redis), `golang-migrate`, MinIO (S3-compatible object storage).
- PostgreSQL is the single source of truth for financial data. Redis is an accelerator/coordinator only — never the only copy of any financial or account data.

## Local development

```bash
cp .env.example .env
docker compose -f compose.yaml -f compose.dev.yaml up --build
```

Host ports (fixed by the plan, loopback-only): PostgreSQL `10001`, Redis `10002`, API `10003`.

Run migrations manually against the dev stack:

```bash
docker compose -f compose.yaml -f compose.dev.yaml run --rm migrate
```

Health checks: `GET /health/live`, `GET /health/ready`.

## Running without Docker

```bash
go run ./cmd/migrate -path ./migrations
go run ./cmd/api
```

Requires `DATABASE_URL` and `REDIS_ADDR` pointing at a reachable PostgreSQL/Redis (see `.env.example`).

## Tests

```bash
go vet ./...
go test ./...
```

## Layout

```text
cmd/            entry points: api, worker, migrate
internal/
  platform/     config, logging, database, redis, storage, http server — no business logic
migrations/     golang-migrate SQL files
openapi/        API contract, grows with each module
```

Business modules (`auth`, `users`, `wallets`, `transactions`, ...) are added under `internal/` as each is implemented, following the roadmap in `/plan.md` section 25.
