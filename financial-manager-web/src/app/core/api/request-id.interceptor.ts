import { HttpInterceptorFn } from '@angular/common/http';

/**
 * Correlation ID on every request, traced through the backend's request ID
 * propagation (plan.md section 22.2), as the app's RequestIdInterceptor.
 */
export const requestIdInterceptor: HttpInterceptorFn = (req, next) =>
  next(
    req.headers.has('X-Request-Id')
      ? req
      : req.clone({ setHeaders: { 'X-Request-Id': crypto.randomUUID() } }),
  );
