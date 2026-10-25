# syntax=docker/dockerfile:1
#
# The web dashboard (plan.md section 9.9, docs/build-deploy.md "Dashboard
# web"): the Angular build served by Caddy on :8080. Built by CI (job
# docker in .github/workflows/web-ci.yml) and published as
# dokjolly/financial-manager-web; the VPS pulls it (service `web` of
# financial-manager-backend/compose.prod.yaml) and never builds it.
#
# Build from the repository root, since the translations come from the
# app's ARB files (scripts/arb-to-json.mjs):
#   docker build -f financial-manager-web/Dockerfile -t financial-manager-web .
# Dockerfile.dockerignore, next to this file, keeps that context small.

FROM node:24.22.0-alpine AS build

WORKDIR /repo/financial-manager-web
COPY financial-manager-web/package.json financial-manager-web/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

COPY financial-manager-app/lib/l10n/ /repo/financial-manager-app/lib/l10n/
COPY financial-manager-web/ ./
# prebuild runs the translation build from the ARB files first.
RUN npm run build

FROM caddy:2.11.7-alpine

COPY financial-manager-web/docker/Caddyfile.web /etc/caddy/Caddyfile
COPY --from=build /repo/financial-manager-web/dist/financial-manager-web/browser /srv
# Android App Links: lets the app open the links in emails
# (docs/build-deploy.md, "App Links").
COPY financial-manager-web/docker/assetlinks.json /srv/.well-known/assetlinks.json

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
