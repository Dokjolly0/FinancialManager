# FinancialManager

A personal finance app for tracking a single wallet: record income and expenses in seconds, browse and search a full transaction history, and understand spending trends over time — without needing any accounting knowledge.

The product is built around four goals: **speed** (a common transaction takes seconds to enter), **reliability** (every balance change is traceable — no direct balance edits, only recorded transactions and explicit adjustments), **readability** (balance, income, expenses, and trend are always understandable), and **extensibility** (the MVP is designed to grow into multiple accounts, budgets, recurring transactions, and bank sync without a rewrite). Amounts are always handled as integer minor units (cents), never floating point, and all dates are stored in UTC and shown in the user's local time zone.

See [`plan.md`](plan.md) for the full product and architecture specification.

## Stack

Flutter (Android + iOS) · Angular 22 + Tailwind CSS (web dashboard) · Go · PostgreSQL · Redis · Docker · MinIO

## Repository structure

- [`financial-manager-backend/`](financial-manager-backend) — Go modular-monolith API (PostgreSQL as the source of truth, Redis as an accelerator/coordinator only, MinIO for images).
- [`financial-manager-app/`](financial-manager-app) — Flutter client for Android and iOS. Its ARB files (`lib/l10n/`) are the strings of both clients.
- [`financial-manager-web/`](financial-manager-web) — the web dashboard at https://financialmanager.alexviolatto.dev: Angular 22 (standalone, zoneless, signals), Tailwind CSS 4 and the Angular CDK; same features as the app except the on-device AI.
- [`plan.md`](plan.md) — full product and architecture spec (screens, data model, API contract, security, roadmap, etc.).

## Getting started

### Backend

```bash
cd financial-manager-backend
cp .env.example .env
docker compose -f compose.yaml -f compose.dev.yaml up --build
```

Default host ports: PostgreSQL `10001`, Redis `10002`, API `10003`, MinIO `10004`. In production the backend runs on the `alex-violatto` VPS behind Caddy, and clients use `https://financialmanager.alexviolatto.dev/api/v1` (the API is published only on `127.0.0.1:10003`); ports are configurable through the backend `.env` file. The production compose also serves the web dashboard (service `web`, on `127.0.0.1:10005` behind the same Caddy): GitHub Actions (`web-ci`) builds its image from `financial-manager-web/Dockerfile` and publishes it to Docker Hub (`dokjolly/financial-manager-web`), the VPS only pulls it. Production updates run with `financial-manager-backend/scripts/deploy.sh`. See [`docs/build-deploy.md`](docs/build-deploy.md) for deploy, HTTPS, the web dashboard and Android release signing. See [`financial-manager-backend/README.md`](financial-manager-backend/README.md) for running without Docker, migrations, and health checks.

### App

```bash
cd financial-manager-app
flutter pub get
flutter run   # an emulator: --dart-define=API_BASE_URL=http://10.0.2.2:10003/v1 for the local backend
```

`flutter pub get`/`flutter run` regenerate the localized strings (`AppLocalizations`, from `lib/l10n/*.arb`) automatically; run `flutter gen-l10n` directly only if you need to regenerate them without building the app.

### Web dashboard

```bash
cd financial-manager-web
npm ci
npm start   # http://localhost:5000, /api proxied to the local backend on :10003
```

Needs Node.js `^22.22.3` or `^24.15.0`. The dev server proxies `/api` to the backend, so no CORS setup is needed, and the links in the development emails (Mailpit, `http://127.0.0.1:10006`) open it. Translations are generated from the app's ARB files. See [`financial-manager-web/README.md`](financial-manager-web/README.md).

## Testing

```bash
# backend
cd financial-manager-backend && go test ./...

# app
cd financial-manager-app && flutter analyze && flutter test

# web dashboard (unit/component tests, then browser smoke tests on the production build)
cd financial-manager-web && npm run lint && npm test -- --watch=false
cd financial-manager-web && npm run build && npm run e2e
```

## Further reading

- [`plan.md`](plan.md) — full specification.
- [`financial-manager-backend/docs/backup-restore.md`](financial-manager-backend/docs/backup-restore.md) — backup and restore procedures.
- [`docs/build-deploy.md`](docs/build-deploy.md) — VPS deployment, the web dashboard image and app builds (Italian).
- [`docs/privacy.md`](docs/privacy.md) — privacy notice, including the AI analysis in the cloud and on the device (Italian).
- [`docs/ai-on-device-spike.md`](docs/ai-on-device-spike.md) — on-device AI prototype: engines, models and measurements (Italian).
- [`financial-manager-app/README.md`](financial-manager-app/README.md) — app structure and the AI analysis modules.
- [`financial-manager-web/README.md`](financial-manager-web/README.md) — web dashboard: running, translations, structure, tests, Docker image.
