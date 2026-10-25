import { HttpErrorResponse, HttpHeaders } from '@angular/common/http';

import { RefreshNetworkError } from '../auth/token-store';
import { fromResponse, toAppError } from './app-error';
import { errorCodeKey } from './error-text';

const envelope = (code: string, field_errors?: Record<string, string>) => ({
  error: { code, message: 'server text', field_errors, request_id: 'req-1' },
});

describe('fromResponse', () => {
  it('maps a generic 401 to an expired session', () => {
    expect(fromResponse(401, envelope('UNAUTHORIZED'), null)).toMatchObject({
      kind: 'session-expired',
    });
    expect(fromResponse(401, null, null).kind).toBe('session-expired');
  });

  it('keeps domain codes of a 401, such as a wrong password', () => {
    expect(fromResponse(401, envelope('INVALID_CREDENTIALS'), null)).toMatchObject({
      kind: 'domain',
      code: 'INVALID_CREDENTIALS',
    });
  });

  it('reads Retry-After only for the platform rate limit', () => {
    expect(fromResponse(429, envelope('RATE_LIMITED'), '30')).toMatchObject({
      kind: 'rate-limited',
      retryAfterSeconds: 30,
    });
    expect(fromResponse(429, envelope('AI_PROVIDER_RATE_LIMITED'), '30')).toMatchObject({
      kind: 'domain',
      code: 'AI_PROVIDER_RATE_LIMITED',
    });
  });

  it('carries field errors', () => {
    expect(
      fromResponse(422, envelope('VALIDATION_ERROR', { email: 'INVALID_EMAIL' }), null),
    ).toMatchObject({
      kind: 'domain',
      fieldErrors: { email: 'INVALID_EMAIL' },
      requestId: 'req-1',
    });
  });

  it('treats an unreachable server as a network error', () => {
    expect(fromResponse(0, null, null).kind).toBe('network');
    expect(fromResponse(502, '<html>', null).kind).toBe('network');
    expect(fromResponse(500, null, null).kind).toBe('unknown');
  });
});

describe('toAppError', () => {
  it('reads HttpErrorResponse and fetch failures', () => {
    const response = new HttpErrorResponse({
      status: 429,
      error: envelope('RATE_LIMITED'),
      headers: new HttpHeaders({ 'Retry-After': '5' }),
    });
    expect(toAppError(response)).toMatchObject({ kind: 'rate-limited', retryAfterSeconds: 5 });
    expect(toAppError(new TypeError('Failed to fetch')).kind).toBe('network');
    expect(toAppError(new RefreshNetworkError()).kind).toBe('network');
    expect(toAppError(new DOMException('stop', 'AbortError')).kind).toBe('cancelled');
  });
});

describe('errorCodeKey', () => {
  it('follows the ARB naming of error_code_localizations.dart', () => {
    expect(errorCodeKey('VALIDATION_ERROR')).toBe('errorCodeValidationError');
    expect(errorCodeKey('INVALID_RFC3339_DATE')).toBe('errorCodeInvalidRfc3339Date');
    expect(errorCodeKey('AI_PROVIDER_CONTEXT_TOO_LONG')).toBe('errorCodeAiProviderContextTooLong');
  });
});
