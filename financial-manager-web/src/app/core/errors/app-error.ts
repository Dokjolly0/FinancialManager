import { HttpErrorResponse } from '@angular/common/http';

import { RefreshNetworkError } from '../auth/token-store';

/**
 * Errors the UI reacts to, mapped from transport failures so screens never
 * look at HTTP statuses (the app's AppError/ErrorMapper, plan.md section
 * 9.5). The backend's envelope is {"error": {code, message, field_errors,
 * request_id}} (section 10.6).
 */
export type AppError =
  | { kind: 'network' }
  | { kind: 'session-expired'; requestId?: string }
  | { kind: 'rate-limited'; retryAfterSeconds?: number; requestId?: string }
  | {
      kind: 'domain';
      code: string;
      message: string;
      fieldErrors: Record<string, string>;
      requestId?: string;
    }
  | { kind: 'cancelled' }
  | { kind: 'unknown'; cause?: unknown };

interface Envelope {
  code: string;
  message: string;
  fieldErrors: Record<string, string>;
  requestId?: string;
}

/** Thrown by code that builds its own AppError (SSE streams, client checks). */
export class AppErrorException extends Error {
  constructor(readonly appError: AppError) {
    super(appError.kind === 'domain' ? appError.code : appError.kind);
  }
}

export function parseEnvelope(body: unknown): Envelope | null {
  if (typeof body !== 'object' || body === null) return null;
  const error = (body as { error?: unknown }).error;
  if (typeof error !== 'object' || error === null) return null;
  const { code, message, field_errors, request_id } = error as Record<string, unknown>;
  if (typeof code !== 'string' || typeof message !== 'string') return null;
  const fieldErrors: Record<string, string> = {};
  if (typeof field_errors === 'object' && field_errors !== null) {
    for (const [field, value] of Object.entries(field_errors)) {
      if (typeof value === 'string') fieldErrors[field] = value;
    }
  }
  return {
    code,
    message,
    fieldErrors,
    requestId: typeof request_id === 'string' ? request_id : undefined,
  };
}

/** Maps an HTTP status, body and Retry-After header to an AppError. */
export function fromResponse(status: number, body: unknown, retryAfter: string | null): AppError {
  if (status === 0) return { kind: 'network' };
  const envelope = parseEnvelope(body);
  // 401 is not only "the access token is invalid": wrong passwords and
  // similar credentials come back as 401 with their own code, and must keep
  // their message instead of "session expired".
  if (status === 401 && (envelope === null || envelope.code === 'UNAUTHORIZED')) {
    return { kind: 'session-expired', requestId: envelope?.requestId };
  }
  // A 429 with its own code (AI_PROVIDER_RATE_LIMITED) is a domain error;
  // only the platform's RATE_LIMITED is "too many attempts".
  if (status === 429 && (envelope === null || envelope.code === 'RATE_LIMITED')) {
    const seconds = Number.parseInt(retryAfter ?? '', 10);
    return {
      kind: 'rate-limited',
      retryAfterSeconds: Number.isFinite(seconds) ? seconds : undefined,
      requestId: envelope?.requestId,
    };
  }
  if (envelope !== null) return { kind: 'domain', ...envelope };
  if (status === 502 || status === 503 || status === 504) return { kind: 'network' };
  return { kind: 'unknown' };
}

/** Any thrown value as an AppError. */
export function toAppError(error: unknown): AppError {
  if (error instanceof AppErrorException) return error.appError;
  if (error instanceof HttpErrorResponse) {
    return fromResponse(error.status, error.error, error.headers?.get('Retry-After') ?? null);
  }
  if (error instanceof RefreshNetworkError) return { kind: 'network' };
  if (error instanceof DOMException && error.name === 'AbortError') return { kind: 'cancelled' };
  // fetch() rejects with a TypeError when the server can't be reached.
  if (error instanceof TypeError) return { kind: 'network' };
  return { kind: 'unknown', cause: error };
}

/** The domain code of an error, if it is one. */
export function errorCode(error: unknown): string | null {
  const appError = toAppError(error);
  return appError.kind === 'domain' ? appError.code : null;
}
