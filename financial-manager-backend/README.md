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

Default dev host ports (loopback-only, configurable in `.env`): PostgreSQL `10001`, Redis `10002`, API `10003`, MinIO `10004`. In production, only the API and the web dashboard (service `web`, `127.0.0.1:10005`, defined in `compose.prod.yaml`) are published, the API on `API_HOST_BIND:API_HOST_PORT` (`127.0.0.1:10003` on the live VPS): the host's Caddy terminates HTTPS and forwards `https://financialmanager.alexviolatto.dev/api/*` to it with the `/api` prefix stripped, so clients use `https://financialmanager.alexviolatto.dev/api/v1`. `TRUSTED_PROXY_CIDRS` lets the API read the real client IP from Caddy's `X-Forwarded-For`. `CORS_ALLOWED_ORIGINS` normally stays empty: the dashboard is same-origin in production, and in development its dev server (`npm start` in `../financial-manager-web`, port 5000) proxies `/api` to the API, which keeps the default dev `APP_PUBLIC_URL` (`http://localhost:5000`) pointing at it. The site block is in [`deploy/Caddyfile.example`](deploy/Caddyfile.example); the full procedure is in [`../docs/build-deploy.md`](../docs/build-deploy.md). Worker metrics stay internal on `9101`.

Production updates go through `./scripts/deploy.sh` on the VPS: `git pull`, then the Go images built one at a time with `--pull` (so a rebuild picks up the base images' security fixes) (never `up -d --build`, which builds them in parallel and strains the 2 GB VPS), the dashboard image pulled, `up -d` and a readiness check. The dashboard (the Angular app in `../financial-manager-web`) is never built on the VPS: CI (`.github/workflows/web-ci.yml`) publishes it to Docker Hub as `dokjolly/financial-manager-web` (`latest` and `sha-<commit>`; `WEB_IMAGE_TAG` pins one for a rollback) and `compose.prod.yaml` runs it with `pull_policy: always`.

The dev stack also runs Mailpit: every email the API sends (verification, password reset) lands there whatever the recipient, readable at `http://127.0.0.1:10006`. In production the API sends through SMTP: `SMTP_PRESET=gmail` (an app password) or `infomaniak`, or `SMTP_HOST`/`SMTP_PORT`/`SMTP_TLS`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM` for any server, plus `APP_PUBLIC_URL`, the base of the links in emails (required in production). Without SMTP nothing is sent and the API logs `email_not_sent_no_provider_configured`. Sending is asynchronous (`internal/email/async.go`), so requests never wait for the mail server; results are logged as `email_sent`/`email_send_failed` and counted in `financialmanager_emails_total`. Setup for each provider: [`../docs/build-deploy.md`](../docs/build-deploy.md), section 12.

Run migrations manually against the dev stack:

```bash
docker compose -f compose.yaml -f compose.dev.yaml run --rm migrate
```

Health checks: `GET /health/live`, `GET /health/ready`.

## Go version

`go.mod` has two lines that matter:

- `go 1.26.0`: the minimum language version (raised by dependencies, e.g. `golang.org/x/net`);
- `toolchain go1.27.3`: the release actually used. CI's `actions/setup-go` installs this one, and a local `go` older than it downloads it automatically (`GOTOOLCHAIN=auto`, the default). It is pinned to the latest patch release because the standard library's security fixes (`net/http`, `crypto/tls`, `crypto/x509`, ...) only arrive in patch releases, and govulncheck reports them.

The Docker images build with `golang:1.27-alpine3.24` and run on `alpine:3.24`; the minor-version tags follow patch releases, and `scripts/deploy.sh` builds with `--pull` to fetch them.

Go supports only the two latest major releases: when a new one comes out (every February and August), move to it.

Updating:

```bash
go mod edit -toolchain=go1.27.4     # new patch release
go get golang.org/x/net@latest      # a dependency flagged by govulncheck
go mod tidy
go build ./... && go vet ./... && go test ./...
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

For a new major release also change the `golang:` tag in `Dockerfile`. Then rebuild the images and scan them like CI does: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image --severity HIGH,CRITICAL --ignore-unfixed financial-manager-api:ci`.

## CI

`.github/workflows/backend-ci.yml`, on pushes to `main` and pull requests that touch this folder:

- `lint-and-test`: `gofmt`, `go vet`, `go test -race`, govulncheck and the OpenAPI lint (Redocly). govulncheck fails only on vulnerabilities the code can actually reach; the others are listed as informational (today one, `golang.org/x/crypto/openpgp`, which has no fix and is not imported).
- `docker-build`: builds the API and worker images and scans them with Trivy, failing on HIGH/CRITICAL findings that have a fix, in both the Alpine packages and the Go binaries.

Runners are pinned to `ubuntu-26.04` (not `ubuntu-latest`, which moves to a new Ubuntu every two years), actions are on releases that run on Node 24, and `trivy-action` is pinned to a commit rather than a tag. `setup-go` caches modules keyed on `go.sum` (`cache-dependency-path`, needed because `go.sum` is not at the repository root).

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
