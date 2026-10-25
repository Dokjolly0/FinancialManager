# FinancialManager — web dashboard

The browser dashboard served at https://financialmanager.alexviolatto.dev: Angular 22 (standalone components, zoneless, signals), Tailwind CSS 4 and the Angular CDK. It talks to the same Go API as the Android/iOS app (`/api/v1` on the same origin) and has the same features, except the on-device AI models, which only run on the phone. Architecture and design decisions: [`../plan.md`](../plan.md), section 9.9.

## Requirements

Node.js `^22.22.3` or `^24.15.0` (Angular 22's minimum) and npm. CI and the Docker image use Node 24.22.

## Run locally

```bash
# the backend (from financial-manager-backend/)
docker compose -f compose.yaml -f compose.dev.yaml up --build

# the dashboard
npm ci
npm start   # http://localhost:5000
```

`npm start` runs `scripts/dev.mjs`: the translation build in watch mode (`arb-to-json.mjs --watch`, so an edit to an ARB or web string file shows up on reload) next to `ng serve`. Arguments after `npm start --` go to `ng serve`.

`ng serve` listens on port 5000 and proxies `/api/*` to the API on `http://localhost:10003` (`proxy.conf.json`, `/api` stripped as the production Caddy does), so the browser sees one origin as in production: no CORS setup is needed, and the links in the emails (`APP_PUBLIC_URL`, `http://localhost:5000` by default in development) open the local dashboard. The development emails land in Mailpit (http://127.0.0.1:10006).

The AI analysis stays unavailable until the backend has `AI_KEY_ENCRYPTION_KEY` (`docs/build-deploy.md`, "Analisi AI").

## Translations

The strings come from the app's ARB files (`../financial-manager-app/lib/l10n/app_{it,en}.arb`), so the app and the dashboard say the same things; Italian and English, following the account's language (`profile.locale`). `scripts/arb-to-json.mjs` merges them with the web-only strings in `src/i18n/web.{it,en}.json` into `public/i18n/{it,en}.json` (gitignored). It runs before `npm start`, `npm run build` and `npm test`, and fails if a language misses a key or a placeholder, or if a web key shadows an ARB key.

Messages are ICU MessageFormat (`{name}`, `plural`, `select`), formatted by a small transpiler of our own (`src/app/core/i18n/icu-transpiler.ts`) instead of `@messageformat/core`, which compiles messages with `new Function` and would need `'unsafe-eval'` in the CSP. Its test formats every ARB message in both languages.

Error codes from the API map to ARB keys in `src/app/core/errors/error-text.ts`, the same mapping as the app's `error_code_localizations.dart`.

## Structure

```
src/app/
  core/      api (base URL, request id, idempotency keys, SSE over fetch), auth (token store,
             refresh interceptor, Google Identity Services), errors, formatting (money in minor
             units, dates), i18n, session (restore, guards, profile), theme, media (images as
             blob URLs), files (downloads)
  shared/ui/ the UI kit: icons (lucide), dialogs and drawers (CDK), form controls, toasts,
             empty/error/loading states, avatar
  layout/    app shell (sidebar, top bar, mobile bottom nav), "Aggiungi" menu, command palette (Ctrl+K)
  features/  auth, home, wallets, transactions, categories, media, history, reports, account, ai
```

Routes (`src/app/app.routes.ts`) keep the app's paths (`lib/app/router.dart`), so bookmarks, email links and Android App Links keep working; each feature page is a lazy chunk. Only two are new: `/app/account/wallets/:id/denominations` and `/app/account/wallets/:id/voucher-lots`, which the app opens without a URL.

Session: the access token lives in memory, the refresh token in `localStorage` (`fm.refresh_token`). A refresh runs inside a Web Lock (`fm.refresh`) and re-reads the stored token first, so two tabs never present the same rotated token (the backend treats a replay as theft and revokes every session). A network failure during refresh keeps the session; an invalid refresh token signs out.

## Scripts

| Command | What it does |
| --- | --- |
| `npm start` | Translations in watch mode + dev server on port 5000 with the API proxy |
| `npm run build` | Production build in `dist/financial-manager-web/browser` |
| `npm test` | Unit and component tests (Vitest) |
| `npm run test:scripts` | Tests of the build scripts (`node --test`) |
| `npm run e2e` | Browser smoke tests (Playwright) on the production build; run `npm run build` first |
| `npm run lint` | ESLint (angular-eslint) |
| `npm run format` / `format:check` | Prettier |

## Tests

- Unit and component tests (`*.spec.ts`, Vitest through `ng test`): session refresh (single flight, multi-tab), SSE parser, money parsing and formatting, error mapping, ICU formatting, "Aggiungi" rules, AI periods.
- Smoke tests (`e2e/`, Playwright, desktop Chrome and Pixel 7): login → home → new operation → history search → reports. The API is mocked in the browser (`e2e/mock-api.ts`) and `e2e/serve.mjs` serves the build with the production CSP read from `../financial-manager-backend/deploy/Caddyfile.example`, so a CSP violation fails the test. The first time: `npx playwright install chromium`.

CI (`.github/workflows/web-ci.yml`) runs format check, lint, unit tests, script tests, the production build and the smoke tests on every push and pull request that touches the dashboard, the ARB files or the Caddy example.

## Docker image

`Dockerfile` builds the dashboard with Node and serves it with Caddy on `:8080` (`docker/Caddyfile.web`): files with a content hash in the name are cached for a year (`immutable`), everything else (`index.html`, translations, icons) is `no-cache`; app routes fall back to `index.html`; `docker/assetlinks.json` is served at `/.well-known/assetlinks.json` for Android App Links. The build context is the repository root, because the translations come from the app's ARB files:

```bash
# from the repository root
docker build -f financial-manager-web/Dockerfile -t financial-manager-web .
docker run --rm -p 8080:8080 financial-manager-web
```

CI publishes it as `dokjolly/financial-manager-web` (`latest` and `sha-<commit>`) on every push to `main`; the VPS only pulls it. Deploy, rollback and the CSP: [`../docs/build-deploy.md`](../docs/build-deploy.md), "Dashboard web".
