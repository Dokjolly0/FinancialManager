import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { MailCheck } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Spinner } from '../../shared/ui/states';
import { AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';

/**
 * Password recovery request (plan.md section 14.1). The same success message
 * whether the address exists or not, like the backend, so accounts can't be
 * enumerated.
 */
@Component({
  selector: 'app-forgot-password-page',
  imports: [AuthLayout, Icon, ReactiveFormsModule, RouterLink, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-auth-layout [heading]="'forgotPasswordScreenTitle' | transloco">
      @if (sent()) {
        <div class="card card-pad text-center">
          <div
            class="mx-auto mb-4 grid h-12 w-12 place-items-center rounded-2xl bg-primary-soft text-primary"
          >
            <app-icon [icon]="MailCheck" />
          </div>
          <p class="text-sm text-fg">{{ 'forgotPasswordSuccessMessage' | transloco }}</p>
        </div>
      } @else {
        <form class="space-y-5" [formGroup]="form" (ngSubmit)="submit()" novalidate>
          <p class="text-sm leading-relaxed text-fg-muted">
            {{ 'forgotPasswordInstructionsMessage' | transloco }}
          </p>
          <div>
            <label class="label" for="fp-email">{{ 'emailLabel' | transloco }}</label>
            <input
              id="fp-email"
              class="input"
              type="email"
              formControlName="email"
              autocomplete="email"
            />
          </div>
          @if (error()) {
            <p class="field-error" role="alert">{{ error() }}</p>
          }
          <button
            type="submit"
            class="btn btn-primary btn-lg w-full"
            [disabled]="submitting() || form.invalid"
          >
            @if (submitting()) {
              <app-spinner />
            }
            {{ 'sendAction' | transloco }}
          </button>
        </form>
      }
      <p class="mt-8 text-center text-sm">
        <a routerLink="/login" class="font-semibold text-primary hover:underline">{{
          'backToLoginAction' | transloco
        }}</a>
      </p>
    </app-auth-layout>
  `,
})
export class ForgotPasswordPage {
  private readonly api = inject(AuthApi);
  private readonly errors = inject(ErrorText);

  protected readonly MailCheck = MailCheck;
  protected readonly form = inject(NonNullableFormBuilder).group({
    email: ['', [Validators.required]],
  });
  protected readonly submitting = signal(false);
  protected readonly sent = signal(false);
  protected readonly error = signal<string | null>(null);

  protected async submit(): Promise<void> {
    if (this.form.invalid) return;
    this.submitting.set(true);
    this.error.set(null);
    try {
      await this.api.forgotPassword(this.form.getRawValue().email.trim());
      this.sent.set(true);
    } catch (error) {
      this.error.set(this.errors.message(error));
    } finally {
      this.submitting.set(false);
    }
  }
}
