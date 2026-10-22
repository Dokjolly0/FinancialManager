#!/usr/bin/env sh
# Updates production on the VPS (docs/build-deploy.md, "Aggiornare il
# backend dopo modifiche"): pulls the repository, builds the Go images one
# at a time, pulls the web dashboard image from Docker Hub, restarts what
# changed and waits for the API to be ready.
#
# Usage: ./scripts/deploy.sh [--no-pull]
#   --no-pull   skip `git pull` (deploy what is checked out)
#
# Why not `up -d --build`: compose builds every image in parallel, and on
# the 1 vCPU / 2 GB VPS three Go builds at once already strain memory.
# The dashboard is never built here (CI publishes it), see compose.prod.yaml.
set -eu
cd "$(dirname "$0")/.."

C="docker compose -f compose.yaml -f compose.prod.yaml"

if [ "${1:-}" != "--no-pull" ]; then
  git -C .. pull --ff-only
fi

# --pull: fetch newer base images (golang, alpine) so a rebuild picks up
# their security fixes.
for service in migrate api worker; do
  echo "==> build $service"
  $C build --pull "$service"
done

echo "==> pull web"
$C pull web

echo "==> up"
$C up -d

# The previous images, now untagged.
docker image prune -f >/dev/null

echo "==> waiting for the API"
i=0
until curl -fsS -o /dev/null "http://127.0.0.1:${API_HOST_PORT:-10003}/health/ready"; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "API not ready after 60s: $C logs api" >&2
    exit 1
  fi
  sleep 2
done
$C ps
echo "deploy ok"
