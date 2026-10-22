# syntax=docker/dockerfile:1
#
# The web dashboard (plan.md section 9, docs/build-deploy.md "Dashboard
# web"): Flutter web build served by Caddy on :8080. Built by
# financial-manager-backend/compose.prod.yaml (service `web`), so
# `docker compose ... up -d --build` on the VPS also updates the dashboard.
#
# Build args:
#   FLUTTER_VERSION  Flutter release used to compile; keep it equal to the
#                    one used for the APK (`flutter --version`)
#   API_BASE_URL     the API as the browser sees it

ARG FLUTTER_VERSION=3.47.2

FROM debian:trixie-slim AS build

ARG FLUTTER_VERSION
ARG API_BASE_URL=https://financialmanager.alexviolatto.dev/api/v1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# The SDK at the release tag; only the web artifacts are downloaded.
RUN git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    PUB_CACHE=/root/.pub-cache
RUN flutter config --no-analytics --no-cli-animations \
    && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos --no-fuchsia \
    && flutter --version

WORKDIR /app
COPY . .

# --no-web-resources-cdn: CanvasKit is served from here, not from
# Google's CDN (no third-party requests, stricter CSP).
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get \
    && flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
       --dart-define=API_BASE_URL="${API_BASE_URL}"

FROM caddy:2.11.7-alpine

COPY docker/Caddyfile.web /etc/caddy/Caddyfile
COPY --from=build /app/build/web /srv

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
