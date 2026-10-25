import {
  HttpContextToken,
  HttpErrorResponse,
  HttpInterceptorFn,
  HttpRequest,
} from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, from, switchMap, throwError } from 'rxjs';

import { API_BASE } from '../api/api';
import { TokenStore } from './token-store';

/** Set on requests that must go out without the access token. */
export const SKIP_AUTH = new HttpContextToken<boolean>(() => false);

/**
 * Attaches the access token to API requests and, when the server says the
 * token is no longer valid, refreshes it once and retries (the app's
 * AuthInterceptor, plan.md section 9.5). A failed refresh ends the session.
 *
 * Only a 401 about the token itself triggers a refresh: the generic
 * UNAUTHORIZED code or no envelope at all. A 401 with a domain code, such as
 * INVALID_CREDENTIALS on login or INVALID_CURRENT_PASSWORD, is the answer.
 */
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  if (!req.url.startsWith(API_BASE) || req.context.get(SKIP_AUTH)) return next(req);
  const tokens = inject(TokenStore);
  const withToken = (token: string | null): HttpRequest<unknown> =>
    token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req;

  return next(withToken(tokens.accessToken)).pipe(
    catchError((error: unknown) => {
      if (!isTokenRejection(error) || !tokens.hasStoredSession()) return throwError(() => error);
      // A RefreshNetworkError propagates as is: the request failed for the
      // network, not the session.
      return from(tokens.refresh()).pipe(
        switchMap((token) => {
          if (token === null) {
            tokens.expire();
            return throwError(() => error);
          }
          return next(withToken(token));
        }),
      );
    }),
  );
};

export function isTokenRejection(error: unknown): boolean {
  if (!(error instanceof HttpErrorResponse) || error.status !== 401) return false;
  const code = (error.error as { error?: { code?: unknown } } | null)?.error?.code;
  return typeof code !== 'string' || code === 'UNAUTHORIZED';
}
