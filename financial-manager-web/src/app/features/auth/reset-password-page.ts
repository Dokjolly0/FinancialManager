import { ChangeDetectionStrategy, Component, inject, input, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { CircleCheck } from 'lucide';

import { TokenStore } from '../../core/auth/token-store';
import { errorCode } from '../../core/errors/app-error';
import { FormErrors } from '../../core/errors/form-errors';
import { Icon } from '../../shared/ui/icon';
import { PasswordInput } from '../../shared/ui/password-input';
import { Spinner } from '../../shared/ui/states';
import { AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';

/**
 * Opened by the link in the "forgot password" email (/reset-password?token=,
 * plan.md section 15.5), signed in or not. Without a token, or once it is
 * used or expired, it only offers to ask for a new link.
 */
@Component({
  selector: 'app-reset-password-page',
  imports: [
    AuthLayout,
    Icon,
    PasswordInput,
    ReactiveFormsModule,
    RouterLink,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-auth-layout [heading]="'resetPasswordScreenTitle' | transloco">
      @if (done()) {
        <div class="card card-pad text-center">
          <app-icon [icon]="CircleCheck" [size]="36" class="mx-auto mb-3 text-credit" />
          <p class="text-sm text-fg">{{ 'resetPasswordSuccessMessage' | transloco }}</p>
          <!-- A full load: the session this page may have had is revoked. -->
          <a href="/login" class="btn btn-primary mt-5">{{ 'loginAction' | transloco }}</a>
        </div>
      } @else if (!token() || expired()) {
        <div class="card card-pad text-center">
          <p class="text-sm text-fg">{{ 'errorCodeInvalidOrExpiredToken' | transloco }}</p>
          <a routerLink="/forgot-password" class="btn btn-primary mt-5">{{
            'requestNewLinkAction' | transloco
          }}</a>
        </div>
      } @else {
        <form class="space-y-5" [formGroup]="form" (ngSubmit)="submit()" novalidate>
          <p class="text-sm leading-relaxed text-fg-muted">
            {{ 'resetPasswordInstructionsMessage' | transloco }}
          </p>
          <div>
            <label class="label" for="rp-new">{{ 'newPasswordLabel' | transloco }}</label>
            <app-password-input
              inputId="rp-new"
              formControlName="password"
              autocomplete="new-password"
            />
          </div>
          <div>
            <label class="label" for="rp-confirm">{{ 'confirmPasswordLabel' | transloco }}</label>
            <app-password-input
              inputId="rp-confirm"
              formControlName="confirm"
              autocomplete="new-password"
              [invalid]="!!errors.fields()['password']"
            />
            @if (errors.fields()['password']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          @if (errors.message()) {
            <p class="field-error" role="alert">{{ errors.message() }}</p>
          }
          <button type="submit" class="btn btn-primary btn-lg w-full" [disabled]="submitting()">
            @if (submitting()) {
              <app-spinner />
            }
            {{ 'resetPasswordAction' | transloco }}
          </button>
        </form>
      }
    </app-auth-layout>
  `,
})
export class ResetPasswordPage {
  readonly token = input<string>();

  private readonly api = inject(AuthApi);
  private readonly tokens = inject(TokenStore);

  protected readonly CircleCheck = CircleCheck;
  protected readonly form = inject(NonNullableFormBuilder).group({ password: [''], confirm: [''] });
  protected readonly submitting = signal(false);
  protected readonly done = signal(false);
  protected readonly expired = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const { password, confirm } = this.form.getRawValue();
    if (password.length < 8) {
      this.errors.check({ password: 'PASSWORD_TOO_SHORT' });
      return;
    }
    if (password !== confirm) {
      this.errors.check({ password: 'PASSWORDS_DO_NOT_MATCH' });
      return;
    }
    this.errors.clear();
    this.submitting.set(true);
    try {
      await this.api.resetPassword(this.token() ?? '', password);
      // The backend revokes every session on reset: one open in this
      // browser is dead too.
      this.tokens.clear();
      this.done.set(true);
    } catch (error) {
      if (errorCode(error) === 'INVALID_OR_EXPIRED_TOKEN') this.expired.set(true);
      else this.errors.fromError(error);
    } finally {
      this.submitting.set(false);
    }
  }
}
