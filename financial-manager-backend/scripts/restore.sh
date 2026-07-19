#!/usr/bin/env bash
# Restores a PostgreSQL backup made by backup.sh into a target database
# (plan.md section 21.10/20.4). Defaults to a "_restore_test" database
# rather than the real one, so running this to verify a backup can never
# accidentally clobber live data — restoring over the real database name
# requires an explicit, unmistakable opt-in.
#
# Usage: ./scripts/restore.sh <dump-file> [target-db] [compose-files...]
#   BACKUP_ENCRYPTION_KEY   required to decrypt a .enc dump
#   CONFIRM_OVERWRITE=yes   required if target-db equals POSTGRES_DB
set -euo pipefail
cd "$(dirname "$0")/.."

DUMP_FILE="${1:?Usage: restore.sh <dump-file> [target-db] [compose-files...]}"
POSTGRES_USER="${POSTGRES_USER:-financial_manager}"
POSTGRES_DB="${POSTGRES_DB:-financial_manager}"
TARGET_DB="${2:-${POSTGRES_DB}_restore_test}"
shift 2 2>/dev/null || shift 1

if [ "$#" -eq 0 ]; then
  set -- compose.yaml compose.dev.yaml
fi
COMPOSE_ARGS=()
for f in "$@"; do COMPOSE_ARGS+=(-f "$f"); done

if [ "$TARGET_DB" = "$POSTGRES_DB" ] && [ "${CONFIRM_OVERWRITE:-}" != "yes" ]; then
  echo "Refusing to restore over the primary database '$TARGET_DB'." >&2
  echo "Set CONFIRM_OVERWRITE=yes if this is really what you want." >&2
  exit 1
fi

WORK_FILE="$DUMP_FILE"
CLEANUP_DECRYPTED=""
if [[ "$DUMP_FILE" == *.enc ]]; then
  : "${BACKUP_ENCRYPTION_KEY:?BACKUP_ENCRYPTION_KEY is required to decrypt $DUMP_FILE}"
  WORK_FILE="${DUMP_FILE%.enc}.tmp"
  openssl enc -d -aes-256-cbc -pbkdf2 -pass "pass:${BACKUP_ENCRYPTION_KEY}" -in "$DUMP_FILE" -out "$WORK_FILE"
  CLEANUP_DECRYPTED="$WORK_FILE"
fi
trap '[ -n "$CLEANUP_DECRYPTED" ] && rm -f "$CLEANUP_DECRYPTED"' EXIT

echo "==> Recreating database '$TARGET_DB'..."
docker compose "${COMPOSE_ARGS[@]}" exec -T postgres \
  psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"$TARGET_DB\";" \
  -c "CREATE DATABASE \"$TARGET_DB\";"

echo "==> Restoring $DUMP_FILE into '$TARGET_DB'..."
docker compose "${COMPOSE_ARGS[@]}" exec -T postgres \
  pg_restore -U "$POSTGRES_USER" -d "$TARGET_DB" --no-owner --clean --if-exists <"$WORK_FILE"

echo "Restored into database '$TARGET_DB'."
