import { inject } from '@angular/core';
import { CanActivateFn, Router, UrlTree } from '@angular/router';

import { SessionService } from './session.service';

/**
 * Route guards with the app's redirect rules (lib/app/router.dart, plan.md
 * section 9.8). The session is restored before the first navigation, so
 * status is never "checking" here. The email links (/reset-password,
 * /verify-email) have no guard: they open with or without a session.
 */

/** Signed-in screens under /app. */
export const authGuard: CanActivateFn = (_route, state) => {
  const session = inject(SessionService);
  const router = inject(Router);
  switch (session.status()) {
    case 'authenticated':
      return true;
    case 'profileIncomplete':
      return router.parseUrl('/register/google-completion');
    default:
      return router.createUrlTree(['/login'], { queryParams: { from: state.url } });
  }
};

/** Login, registration and forgot-password: signed-in users go to the app. */
export const guestGuard: CanActivateFn = (route) => {
  const session = inject(SessionService);
  const router = inject(Router);
  switch (session.status()) {
    case 'authenticated':
      return afterSignIn(router, route.queryParamMap.get('from'));
    case 'profileIncomplete':
      return router.parseUrl('/register/google-completion');
    default:
      return true;
  }
};

/** The Google completion form, only between Google sign-in and completion. */
export const googleCompletionGuard: CanActivateFn = () => {
  const session = inject(SessionService);
  const router = inject(Router);
  if (session.status() === 'profileIncomplete' && session.pendingGoogle()) return true;
  return router.parseUrl(session.status() === 'authenticated' ? '/app/home' : '/login');
};

/** AI screens: gone when the user turned the AI features off (section 32.10). */
export const aiGuard: CanActivateFn = () =>
  inject(SessionService).aiEnabled() ? true : inject(Router).parseUrl('/app/account');

/**
 * Where to go once signed in: back to the page that asked for the sign-in
 * when it is an app page or an email link, else home.
 */
export function afterSignIn(router: Router, from: string | null | undefined): UrlTree {
  if (from && (from.startsWith('/app/') || isEmailLink(from))) return router.parseUrl(from);
  return router.parseUrl('/app/home');
}

export function isEmailLink(url: string): boolean {
  const path = url.split('?')[0];
  return path === '/reset-password' || path === '/verify-email';
}
