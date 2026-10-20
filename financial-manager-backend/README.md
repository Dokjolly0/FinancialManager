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

Default dev host ports (loopback-only, configurable in `.env`): PostgreSQL `10001`, Redis `10002`, API `10003`, MinIO `10004`. In production, only the API is published, by default on `0.0.0.0:10003`, and clients reach it at `http://83.228.246.84:10003/v1`. Worker metrics stay internal on `9101`.

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

## AI analysis

Optional, off until `AI_KEY_ENCRYPTION_KEY` is set (32 bytes, base64: `openssl rand -base64 32`). Users bring their own provider key (Anthropic, OpenAI, Gemini or any OpenAI-compatible server). Keys are stored encrypted (`internal/platform/secretbox`), and the server streams the report back over Server-Sent Events. Code lives in `internal/ai` (settings, data collection, conversation), `internal/ai/prompt` (versioned, embedded templates with golden tests: `go test ./internal/ai/prompt -update` rewrites them) and `internal/ai/provider` (one streaming adapter per provider, SSRF-safe HTTP client). Spec: `/plan.md` section 32. Deployment notes, including reverse-proxy settings for streaming: `/docs/build-deploy.md`.

## Layout

```text
cmd/            entry points: api, worker, migrate
internal/
  platform/     config, logging, database, redis, storage, http server — no business logic
migrations/     golang-migrate SQL files
openapi/        API contract, grows with each module
```

Business modules (`auth`, `users`, `wallets`, `transactions`, ...) are added under `internal/` as each is implemented, following the roadmap in `/plan.md` section 25.
