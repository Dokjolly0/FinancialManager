# FinancialManager

A personal finance app for tracking a single wallet: record income and expenses in seconds, browse and search a full transaction history, and understand spending trends over time — without needing any accounting knowledge.

The product is built around four goals: **speed** (a common transaction takes seconds to enter), **reliability** (every balance change is traceable — no direct balance edits, only recorded transactions and explicit adjustments), **readability** (balance, income, expenses, and trend are always understandable), and **extensibility** (the MVP is designed to grow into multiple accounts, budgets, recurring transactions, and bank sync without a rewrite). Amounts are always handled as integer minor units (cents), never floating point, and all dates are stored in UTC and shown in the user's local time zone.

See [`plan.md`](plan.md) for the full product and architecture specification.

## Stack

Flutter (Android + iOS + web dashboard) · Go · PostgreSQL · Redis · Docker · MinIO

## Repository structure

- [`financial-manager-backend/`](financial-manager-backend) — Go modular-monolith API (PostgreSQL as the source of truth, Redis as an accelerator/coordinator only, MinIO for images).
- [`financial-manager-app/`](financial-manager-app) — Flutter client: the Android/iOS app and, built for the browser, the web dashboard at https://financialmanager.alexviolatto.dev.
- [`plan.md`](plan.md) — full product and architecture spec (screens, data model, API contract, security, roadmap, etc.).

## Getting started

### Backend

```bash
cd financial-manager-backend
cp .env.example .env
docker compose -f compose.yaml -f compose.dev.yaml up --build
```

Default host ports: PostgreSQL `10001`, Redis `10002`, API `10003`, MinIO `10004`. In production the backend runs on the `alex-violatto` VPS behind Caddy, and clients use `https://financialmanager.alexviolatto.dev/api/v1` (the API is published only on `127.0.0.1:10003`); ports are configurable through the backend `.env` file. The production compose also serves the web dashboard (service `web`, on `127.0.0.1:10005` behind the same Caddy): GitHub Actions builds its image and publishes it to Docker Hub (`dokjolly/financial-manager-web`), the VPS only pulls it. Production updates run with `financial-manager-backend/scripts/deploy.sh`. See [`docs/build-deploy.md`](docs/build-deploy.md) for deploy, HTTPS, the web dashboard and Android release signing. See [`financial-manager-backend/README.md`](financial-manager-backend/README.md) for running without Docker, migrations, and health checks.

### App

```bash
cd financial-manager-app
flutter pub get
flutter run
# web dashboard against the local backend (CORS_ALLOWED_ORIGINS=http://localhost:5000 in its .env)
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:10003/v1
```

`flutter pub get`/`flutter run` regenerate the localized strings (`AppLocalizations`, from `lib/l10n/*.arb`) automatically; run `flutter gen-l10n` directly only if you need to regenerate them without building the app.

## Testing

```bash
# backend
cd financial-manager-backend && go test ./...

# app
cd financial-manager-app && flutter test
```

## Further reading

- [`plan.md`](plan.md) — full specification.
- [`financial-manager-backend/docs/backup-restore.md`](financial-manager-backend/docs/backup-restore.md) — backup and restore procedures.
- [`docs/build-deploy.md`](docs/build-deploy.md) — VPS deployment and app builds (Italian).
- [`docs/privacy.md`](docs/privacy.md) — privacy notice, including the AI analysis in the cloud and on the device (Italian).
- [`docs/ai-on-device-spike.md`](docs/ai-on-device-spike.md) — on-device AI prototype: engines, models and measurements (Italian).
- [`financial-manager-app/README.md`](financial-manager-app/README.md) — app structure and the AI analysis modules.
