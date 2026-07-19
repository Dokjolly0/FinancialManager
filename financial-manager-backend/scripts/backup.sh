#!/usr/bin/env bash
# Backs up PostgreSQL (pg_dump, custom format) and the object storage
# bucket (mirrored via a throwaway minio/mc container — no host install
# required) for whichever `docker compose` stack is currently up (plan.md
# section 21.10). Redis is deliberately not backed up here — it holds
# caches/rate limits/idempotency records, never the source of truth
# (plan.md section 20.4: "Redis non è parte del backup finanziario
# principale").
#
# Usage: ./scripts/backup.sh [compose-files...]
#   BACKUP_DIR              where backups are written (default ./backups)
#   BACKUP_ENCRYPTION_KEY   if set, both backups are encrypted with it
#                           (openssl aes-256-cbc); keep this in a secret
#                           manager in staging/production, never in .env
#   RETENTION_DAYS          prune backups older than this (default 30)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -eq 0 ]; then
  set -- compose.yaml compose.dev.yaml
fi
COMPOSE_ARGS=()
for f in "$@"; do COMPOSE_ARGS+=(-f "$f"); done

POSTGRES_USER="${POSTGRES_USER:-financial_manager}"
POSTGRES_DB="${POSTGRES_DB:-financial_manager}"
OBJECT_STORAGE_BUCKET="${OBJECT_STORAGE_BUCKET:-financial-manager-media}"
OBJECT_STORAGE_ACCESS_KEY="${OBJECT_STORAGE_ACCESS_KEY:-financial_manager}"
OBJECT_STORAGE_SECRET_KEY="${OBJECT_STORAGE_SECRET_KEY:-financial_manager_secret}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NETWORK="financial-manager_backend_internal"

mkdir -p "$BACKUP_DIR/postgres" "$BACKUP_DIR/object-storage"

encrypt_in_place() {
  local plain="$1"
  if [ -n "${BACKUP_ENCRYPTION_KEY:-}" ]; then
    openssl enc -aes-256-cbc -pbkdf2 -salt -pass "pass:${BACKUP_ENCRYPTION_KEY}" -in "$plain" -out "${plain}.enc"
    rm -f "$plain"
    echo "${plain}.enc"
  else
    echo "$plain"
  fi
}

echo "==> Backing up PostgreSQL ($POSTGRES_DB)..."
DUMP_PATH="$BACKUP_DIR/postgres/${TIMESTAMP}.dump"
docker compose "${COMPOSE_ARGS[@]}" exec -T postgres \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc >"$DUMP_PATH"
DUMP_PATH="$(encrypt_in_place "$DUMP_PATH")"
echo "    -> $DUMP_PATH"

echo "==> Mirroring object storage bucket ($OBJECT_STORAGE_BUCKET)..."
MIRROR_DIR="$BACKUP_DIR/object-storage/${TIMESTAMP}"
mkdir -p "$MIRROR_DIR"
docker run --rm --network "$NETWORK" --entrypoint sh \
  -v "$(pwd)/$MIRROR_DIR:/backup" \
  minio/mc:latest -c "
    mc alias set src http://object-storage:9000 '$OBJECT_STORAGE_ACCESS_KEY' '$OBJECT_STORAGE_SECRET_KEY' >/dev/null &&
    mc mirror --quiet src/$OBJECT_STORAGE_BUCKET /backup
  "
TAR_PATH="$BACKUP_DIR/object-storage/${TIMESTAMP}.tar.gz"
tar -C "$BACKUP_DIR/object-storage" -czf "$TAR_PATH" "${TIMESTAMP}"
rm -rf "$MIRROR_DIR"
TAR_PATH="$(encrypt_in_place "$TAR_PATH")"
echo "    -> $TAR_PATH"

echo "==> Pruning backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR/postgres" -type f -mtime "+${RETENTION_DAYS}" -print -delete
find "$BACKUP_DIR/object-storage" -maxdepth 1 -type f -mtime "+${RETENTION_DAYS}" -print -delete

echo "Backup complete."
