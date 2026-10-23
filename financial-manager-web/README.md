# FinancialManager — web dashboard

The browser dashboard served at https://financialmanager.alexviolatto.dev: Angular 22 (standalone components, zoneless, signals), Tailwind CSS 4 and the Angular CDK. It talks to the same Go API as the Android/iOS app (`/api/v1` on the same origin) and has the same features, except the on-device AI models, which only run on the phone.

## Requirements

Node.js `^22.22.3` or `^24.15.0` (Angular 22's minimum) and npm.

## Run locally

```bash
# the backend (from financial-manager-backend/)
docker compose -f compose.yaml -f compose.dev.yaml up --build

# the dashboard
npm ci
npm start   # http://localhost:5000
```

`ng serve` listens on port 5000 and proxies `/api/*` to the API on `http://localhost:10003` (`proxy.conf.json`, `/api` stripped as the production Caddy does), so the browser sees one origin as in production: no CORS setup is needed, and the links in the emails (`APP_PUBLIC_URL`, `http://localhost:5000` by default in development) open the local dashboard.

## Translations

The strings come from the app's ARB files (`../financial-manager-app/lib/l10n/app_{it,en}.arb`), so the app and the dashboard say the same things. `scripts/arb-to-json.mjs` merges them with the web-only strings in `src/i18n/web.{it,en}.json` into `public/i18n/{it,en}.json` (gitignored). It runs before `npm start`, `npm run build` and `npm test`, and fails if a language misses a key or a placeholder. Messages are ICU MessageFormat, read by Transloco's messageformat transpiler.

## Scripts

| Command | What it does |
| --- | --- |
| `npm start` | Dev server on port 5000 with the API proxy |
| `npm run build` | Production build in `dist/financial-manager-web/browser` |
| `npm test` | Unit and component tests (Vitest) |
| `npm run test:scripts` | Tests of the build scripts (`node --test`) |
| `npm run lint` | ESLint (angular-eslint) |
| `npm run format` | Prettier |
