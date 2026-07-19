#!/usr/bin/env bash
# Verifies the most recent backup can actually be restored and contains
# data consistent with the source (plan.md section 20.4: "test periodico
# restore" — a backup nobody has ever restored is not a backup). Meant to
# run on a schedule (cron/CI), separate from the backup itself.
#
# Caveat: this compares row counts against the *live* source database at
# verification time, not a snapshot taken when the backup was made, so a
# mismatch briefly after new writes is expected/benign — investigate only
# a mismatch that persists across re-runs.
#
# Usage: ./scripts/test-restore.sh [compose-files...]
set -euo pipefail
cd "$(dirname "$0")/.."

POSTGRES_USER="${POSTGRES_USER:-financial_manager}"
POSTGRES_DB="${POSTGRES_DB:-financial_manager}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"

if [ "$#" -eq 0 ]; then
  set -- compose.yaml compose.dev.yaml
fi
COMPOSE_ARGS=()
for f in "$@"; do COMPOSE_ARGS+=(-f "$f"); done

LATEST="$(ls -t "$BACKUP_DIR"/postgres/*.dump* 2>/dev/null | head -1 || true)"
if [ -z "$LATEST" ]; then
  echo "No backup found in $BACKUP_DIR/postgres — run backup.sh first." >&2
  exit 1
fi

TEST_DB="restore_verify_$(date +%s)"
echo "==> Verifying $LATEST via a throwaway database '$TEST_DB'..."
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-}" ./scripts/restore.sh "$LATEST" "$TEST_DB" "$@"

FAILED=0
for TABLE in users wallets transactions; do
  SOURCE_COUNT="$(docker compose "${COMPOSE_ARGS[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM $TABLE")"
  RESTORED_COUNT="$(docker compose "${COMPOSE_ARGS[@]}" exec -T postgres psql -U "$POSTGRES_USER" -d "$TEST_DB" -tAc "SELECT count(*) FROM $TABLE")"
  if [ "$SOURCE_COUNT" != "$RESTORED_COUNT" ]; then
    echo "MISMATCH in $TABLE: source=$SOURCE_COUNT restored=$RESTORED_COUNT" >&2
    FAILED=1
  else
    echo "    $TABLE: OK ($SOURCE_COUNT rows)"
  fi
done

echo "==> Dropping throwaway database '$TEST_DB'..."
docker compose "${COMPOSE_ARGS[@]}" exec -T postgres \
  psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE \"$TEST_DB\";"

if [ "$FAILED" -ne 0 ]; then
  echo "Restore verification FAILED." >&2
  exit 1
fi
echo "Restore verification passed."
