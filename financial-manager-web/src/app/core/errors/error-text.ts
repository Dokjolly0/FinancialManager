import { Injectable, inject } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

import { AppError, toAppError } from './app-error';

/**
 * ARB key for an error code: "VALIDATION_ERROR" → "errorCodeValidationError",
 * the naming of the app's error_code_localizations.dart (backend sentinels
 * and Field* codes, plus client-only codes such as INVALID_AMOUNT).
 */
export function errorCodeKey(code: string): string {
  const pascal = code
    .toLowerCase()
    .split('_')
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join('');
  return `errorCode${pascal}`;
}

export interface ErrorPresentation {
  message: string;
  /** Per-field messages a form shows inline (field_errors). */
  fieldErrors: Record<string, string>;
}

/**
 * Text for errors, always from the translations and never server-supplied
 * text, so it follows the user's language (the app's presentError).
 */
@Injectable({ providedIn: 'root' })
export class ErrorText {
  private readonly transloco = inject(TranslocoService);

  /**
   * Localized text of a code; unknown codes give the generic message. A
   * camelCase value is taken as an ARB key, for client-side checks whose
   * text isn't an error code (e.g. "transferSameWalletError").
   */
  code(code: string): string {
    const key = /^[a-z]/.test(code) ? code : errorCodeKey(code);
    const translation = this.transloco.getTranslation(this.transloco.getActiveLang());
    return key in translation
      ? this.transloco.translate(key)
      : this.transloco.translate('errorCodeUnknownError');
  }

  present(error: unknown): ErrorPresentation {
    const appError: AppError = toAppError(error);
    switch (appError.kind) {
      case 'network':
        return { message: this.transloco.translate('errorCodeNetworkError'), fieldErrors: {} };
      case 'session-expired':
        return { message: this.transloco.translate('errorCodeSessionExpired'), fieldErrors: {} };
      case 'rate-limited':
        return {
          message:
            appError.retryAfterSeconds === undefined
              ? this.transloco.translate('errorCodeRateLimitedGeneric')
              : this.transloco.translate('errorCodeRateLimitedWithSeconds', {
                  seconds: appError.retryAfterSeconds,
                }),
          fieldErrors: {},
        };
      case 'domain': {
        const fieldErrors: Record<string, string> = {};
        for (const [field, fieldCode] of Object.entries(appError.fieldErrors)) {
          fieldErrors[field] = this.field(fieldCode, appError.code);
        }
        return { message: this.code(appError.code), fieldErrors };
      }
      default:
        return { message: this.transloco.translate('errorCodeUnknownError'), fieldErrors: {} };
    }
  }

  message(error: unknown): string {
    return this.present(error).message;
  }

  /**
   * Text of one field error. A code without text (an older or newer
   * backend, or a server message instead of a code) falls back to the text
   * of the error's own code, e.g. "Username già in uso".
   */
  field(fieldCode: string, errorCode?: string): string {
    const text = this.code(fieldCode);
    if (text === this.transloco.translate('errorCodeUnknownError') && errorCode) {
      return this.code(errorCode);
    }
    return text;
  }
}
