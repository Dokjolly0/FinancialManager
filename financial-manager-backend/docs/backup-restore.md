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

## Off-site backups to Google Drive

The worker (`cmd/worker`) uploads encrypted backups to a Google Drive
folder. It is on by default under `compose.prod.yaml` and off elsewhere
(`BACKUP_ENABLED`), so the normal deploy command is all it takes:
`docker compose -f compose.yaml -f compose.prod.yaml up -d --build`.

What is uploaded, and how long it is kept:

| Artifact | Drive file name | Retention |
| --- | --- | --- |
| PostgreSQL dump (`pg_dump -Fc`) | `fm-<YYYYMMDDTHHMMSSZ>-postgres.dump.enc` | every dump of the last `BACKUP_RETENTION_DAYS` (30) days + the first dump of each of the last `BACKUP_RETENTION_MONTHS` (12) months; the newest is never deleted |
| Media bucket (`tar.gz`) | `fm-media-latest.tar.gz.enc`, `fm-media-previous.tar.gz.enc` | two copies, rotated: the new archive is uploaded under a temporary name first and only then are the old ones demoted/deleted, so a complete archive always exists |

- Both files are encrypted with `BACKUP_ENCRYPTION_KEY` in the same
  format as `scripts/backup.sh` (`openssl enc -aes-256-cbc -pbkdf2`), so
  the restore procedure below is the same as for local backups. **Keep a
  copy of the key off the server**: the backups are useless without it.
- The worker checks every hour and backs up when the newest dump on Drive
  is older than `BACKUP_INTERVAL` (24h). Restarts don't cause extra
  backups; a missed day is caught up at the next check.
- The database is uploaded before the media archive is built: a media
  failure never costs the database backup.
- Monitoring: `financialmanager_job_runs_total{job="backup"}` and
  `financialmanager_backup_last_success_timestamp_seconds` on the worker's
  `:9101/metrics`; alert when `time() - last_success > 26h`. Logs:
  `backup_ok`, `backup_skipped_not_due`, `backup_failed`,
  `backup_not_configured`.
- A missing or invalid backup setting (credentials, encryption key,
  malformed `BACKUP_*` value) never stops the worker: its other jobs keep
  running, and every hourly check logs `backup_not_configured` with the
  list of problems and counts a failed `backup` run until it's fixed.

### One-time Google setup

A personal Gmail account can't use a service account (service accounts
have no My Drive storage quota), so the worker uses an OAuth client and a
refresh token:

1. In the Google Cloud Console project already used for Google sign-in,
   enable the **Google Drive API**.
2. **OAuth consent screen**: user type External, add your account as a
   test user if asked, then set the publishing status to **In
   production**. While in "Testing", refresh tokens expire after 7 days
   and backups stop. The only scope used, `drive.file`, is non-sensitive,
   so no Google verification is needed.
3. **Credentials → Create credentials → OAuth client ID**, application
   type **Desktop app**. Note the client ID and secret.
4. On your own computer (it needs a browser), from
   `financial-manager-backend`:

   ```bash
   go run ./cmd/gdrive-auth -client-id <id> -client-secret <secret>
   ```

   Open the printed URL, sign in with the account that will hold the
   backups and accept. The command prints `GDRIVE_REFRESH_TOKEN=...`.
5. In the server's `.env` set `GDRIVE_CLIENT_ID`, `GDRIVE_CLIENT_SECRET`,
   `GDRIVE_REFRESH_TOKEN` and `BACKUP_ENCRYPTION_KEY`
   (`openssl rand -base64 48`), then redeploy.

The worker creates the `BACKUP_GDRIVE_FOLDER_NAME` folder ("FinancialManager
Backups") itself. Don't create it by hand: with the `drive.file` scope the
app only sees files and folders it created. For the same reason, files you
upload into that folder by hand are invisible to it and never pruned.

#### Keeping the backups in a subfolder

`BACKUP_GDRIVE_FOLDER_NAME` is the name of a single folder, not a path:
`Backup/Databases/FinancialManager` would create one folder at the Drive
root with slashes in its name. To keep the backups in, for example,
`Backup/Databases/FinancialManager`:

1. Set `BACKUP_GDRIVE_FOLDER_NAME=FinancialManager`.
2. Let the first backup create `FinancialManager` at the Drive root.
3. In the Drive web UI, move that folder into `Backup/Databases/`.

The worker looks the folder up by name among the files it created,
wherever they are. The `drive.file` access stays attached to the folder
when it's moved, so later backups keep landing there.

The app doesn't create the whole path itself because it can't see folders
you created: if `Backup/Databases` already exists, it would create a
second `Backup` folder at the root.

- Don't rename the folder in Drive, or update `BACKUP_GDRIVE_FOLDER_NAME`
  to match. Otherwise the worker no longer finds it and creates a new one
  at the root.
- If the folder is deleted, the next backup recreates it at the root.

### Restoring from Drive

Database: download the dump you want from Drive into the backend folder,
then run the usual script. It restores into `<db>_restore_test` unless
told otherwise, see `scripts/restore.sh`:

```bash
BACKUP_ENCRYPTION_KEY=... ./scripts/restore.sh fm-20261001T030000Z-postgres.dump.enc
```

Media: decrypt and extract the archive, then mirror it back into the
bucket:

```bash
mkdir -p media-restore
openssl enc -d -aes-256-cbc -pbkdf2 -pass "pass:$BACKUP_ENCRYPTION_KEY" \
  -in fm-media-latest.tar.gz.enc | tar -xz -C media-restore
docker run --rm --network financial-manager_backend_internal --entrypoint sh \
  -v "$(pwd)/media-restore:/restore" minio/mc:latest -c "
    mc alias set dst http://object-storage:9000 '$OBJECT_STORAGE_ACCESS_KEY' '$OBJECT_STORAGE_SECRET_KEY' &&
    mc mirror /restore dst/$OBJECT_STORAGE_BUCKET"
```

Restoring an older database dump next to the latest media archive is
safe for balances and transactions. At worst a few images are missing,
for assets the orphan cleanup had already removed.

## Scheduling

The Drive backup above needs no external scheduler. The local scripts,
still useful for an extra on-host copy and for periodic restore tests,
must be run from a cron/scheduler external to the application container,
for example:

```cron
0 3 * * * cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/backup.sh compose.yaml compose.prod.yaml >> /var/log/fm-backup.log 2>&1
0 5 * * 0 cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/test-restore.sh compose.yaml compose.prod.yaml >> /var/log/fm-restore-test.log 2>&1
```

A `test-restore.sh` failure is an alertable event (plan.md section
22.3: "Backup failed").
