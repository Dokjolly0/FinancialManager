# Backup and restore

Implements plan.md section 20.4/21.10. Covers PostgreSQL (the source of truth
for balances and transactions) and the object storage bucket (images).
Redis is intentionally excluded: it only holds cache, rate limits, and
idempotency records — never the only copy of any data (plan.md section 20.4/12.4).

## Scripts

- `scripts/backup.sh` — runs `pg_dump` (custom format) and mirrors the
  bucket with a disposable `minio/mc` container (no installation required
  on the host beyond Docker and `openssl`). If `BACKUP_ENCRYPTION_KEY` is
  set, both backups are encrypted (`openssl enc -aes-256-cbc`). Applies
  retention (`RETENTION_DAYS`, default 30), deleting older backups.
- `scripts/restore.sh <dump-file> [target-db] [compose-files...]` — restores
  into a target database, defaulting to `<db>_restore_test` so the real one
  can never be overwritten by mistake (requires an explicit
  `CONFIRM_OVERWRITE=yes` to do so).
- `scripts/test-restore.sh` — takes the latest backup, restores it into a
  disposable database, compares the row counts of `users`/`wallets`/
  `transactions` against the live source, then drops the test database.
  Implements the "periodic restore test" required by the plan: a backup
  that has never been restored is not a backup.

All scripts must be run from the `financial-manager-backend` folder with
the Docker stack already up (`docker compose -f compose.yaml -f
compose.dev.yaml up -d`, or the staging/production equivalent).

## Retention and encryption

- **Local/development**: a short retention (e.g. 7 days) is sufficient;
  `BACKUP_ENCRYPTION_KEY` is optional.
- **Staging/production**: `BACKUP_ENCRYPTION_KEY` must come from the
  environment's secret manager, never from `.env` (plan.md section 19.4).
  The recommended retention should be confirmed with the product owner
  based on legal/product requirements — 30 daily + 12 monthly is a
  reasonable starting point, not a final policy.
- Backups must be written to storage distinct from production (never the
  same Docker volume) — these scripts write locally (`BACKUP_DIR`, default
  `./backups`) for simplicity; in production `BACKUP_DIR` must point to
  external storage with restricted access.

## Scheduling

Must be run from a cron/scheduler external to the application container,
for example:

```cron
0 3 * * * cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/backup.sh compose.yaml compose.prod.yaml >> /var/log/fm-backup.log 2>&1
0 5 * * 0 cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/test-restore.sh compose.yaml compose.prod.yaml >> /var/log/fm-restore-test.log 2>&1
```

A `test-restore.sh` failure is an alertable event (plan.md section
22.3: "Backup failed").
