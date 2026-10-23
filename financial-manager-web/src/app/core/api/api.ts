import { HttpHeaders } from '@angular/common/http';

/**
 * Root of the API as the browser sees it. Production serves the dashboard and
 * the API on one origin (the host's Caddy proxies /api/* to the backend with
 * the prefix stripped); `ng serve` does the same through proxy.conf.json.
 */
export const API_BASE = '/api/v1';

/** Absolute API path for a route such as "/wallets". */
export function api(path: string): string {
  return `${API_BASE}${path.startsWith('/') ? path : `/${path}`}`;
}

/**
 * Turns a route path the backend returns (always "/v1/...", relative to the
 * API root, e.g. an export's download_url) into a URL under API_BASE, keeping
 * the /api prefix (like the app's resolveApiPath).
 */
export function resolveApiPath(path: string): string {
  const root = API_BASE.replace(/\/v1\/?$/, '');
  return `${root}${path.startsWith('/') ? path : `/${path}`}`;
}

/** A fresh Idempotency-Key header for create requests (plan.md section 10.7). */
export function idempotencyHeaders(): HttpHeaders {
  return new HttpHeaders({ 'Idempotency-Key': crypto.randomUUID() });
}

/** Query parameters without the null/undefined/empty values. */
export function query(
  params: Record<string, string | number | boolean | null | undefined>,
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined || value === '') continue;
    out[key] = String(value);
  }
  return out;
}
