# FinancialManager

A personal finance app for tracking a single wallet: record income and expenses in seconds, browse and search a full transaction history, and understand spending trends over time — without needing any accounting knowledge.

The product is built around four goals: **speed** (a common transaction takes seconds to enter), **reliability** (every balance change is traceable — no direct balance edits, only recorded transactions and explicit adjustments), **readability** (balance, income, expenses, and trend are always understandable), and **extensibility** (the MVP is designed to grow into multiple accounts, budgets, recurring transactions, and bank sync without a rewrite). Amounts are always handled as integer minor units (cents), never floating point, and all dates are stored in UTC and shown in the user's local time zone.

See [`plan.md`](plan.md) for the full product and architecture specification.

## Stack

Flutter (Android + iOS) · Go · PostgreSQL · Redis · Docker · MinIO

## Repository structure

- [`financial-manager-backend/`](financial-manager-backend) — Go modular-monolith API (PostgreSQL as the source of truth, Redis as an accelerator/coordinator only, MinIO for images).
- [`financial-manager-app/`](financial-manager-app) — Flutter mobile client.
- [`plan.md`](plan.md) — full product and architecture spec (screens, data model, API contract, security, roadmap, etc.).

## Getting started

### Backend

```bash
cd financial-manager-backend
cp .env.example .env
docker compose -f compose.yaml -f compose.dev.yaml up --build
```

Fixed host ports: PostgreSQL `10001`, Redis `10002`, API `10003`. See [`financial-manager-backend/README.md`](financial-manager-backend/README.md) for running without Docker, migrations, and health checks.

### App

```bash
cd financial-manager-app
flutter pub get
flutter run
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
