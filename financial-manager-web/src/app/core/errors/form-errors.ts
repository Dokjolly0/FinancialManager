import { computed, inject, signal } from '@angular/core';

import { toAppError } from './app-error';
import { ErrorText } from './error-text';

/**
 * Error state of a form: a general message plus per-field messages, from
 * client-side checks (error codes such as PASSWORD_TOO_SHORT) or from the
 * server's field_errors, both localized the same way. Create it in a
 * component field initializer (it injects ErrorText).
 */
export class FormErrors {
  private readonly text = inject(ErrorText);
  private readonly codes = signal<Record<string, string>>({});
  private readonly errorCode = signal<string | undefined>(undefined);

  /** The general message, e.g. "Username già in uso", or null. */
  readonly message = signal<string | null>(null);

  /** Localized message for each field with an error. */
  readonly fields = computed(() => {
    const out: Record<string, string> = {};
    for (const [field, code] of Object.entries(this.codes())) {
      out[field] = this.text.field(code, this.errorCode());
    }
    return out;
  });

  /** Fields the server or the client flagged. */
  readonly fieldNames = computed(() => Object.keys(this.codes()));

  /** Client-side checks: field → error code. True if there were none. */
  check(codes: Record<string, string>): boolean {
    this.codes.set(codes);
    this.errorCode.set(undefined);
    this.message.set(null);
    return Object.keys(codes).length === 0;
  }

  /** A failed request: its message and any field errors. */
  fromError(error: unknown): void {
    const appError = toAppError(error);
    this.message.set(this.text.message(error));
    if (appError.kind === 'domain') {
      this.codes.set(appError.fieldErrors);
      this.errorCode.set(appError.code);
    } else {
      this.codes.set({});
      this.errorCode.set(undefined);
    }
  }

  clear(): void {
    this.check({});
  }
}
