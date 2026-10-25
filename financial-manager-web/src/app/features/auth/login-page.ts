import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  inject,
  input,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';

import { GoogleIdentity } from '../../core/auth/google-identity';
import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { afterSignIn } from '../../core/session/guards';
import { SessionService } from '../../core/session/session.service';
import { GoogleButton } from '../../shared/ui/google-button';
import { PasswordInput } from '../../shared/ui/password-input';
import { Spinner } from '../../shared/ui/states';
import { AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';

/**
 * Login (plan.md section 7.2). Google is a linked identity, not a separate
 * account (section 15.1): a linked Google account signs in directly, a new
 * one goes on to complete the registration.
 */
@Component({
  selector: 'app-login-page',
  imports: [
    AuthLayout,
    GoogleButton,
    PasswordInput,
    ReactiveFormsModule,
    RouterLink,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-auth-layout
      [heading]="'loginAction' | transloco"
      [subheading]="'webLoginSubtitle' | transloco"
    >
      <form class="space-y-5" [formGroup]="form" (ngSubmit)="submit()" novalidate>
        @if (errors.message()) {
          <div
            class="rounded-xl border border-debit/30 bg-debit/5 px-4 py-3 text-sm text-debit"
            role="alert"
          >
            {{ errors.message() }}
          </div>
        }
        <div>
          <label class="label" for="login-user">{{ 'usernameOrEmailLabel' | transloco }}</label>
          <input
            id="login-user"
            class="input"
            formControlName="usernameOrEmail"
            autocomplete="username"
            [attr.aria-invalid]="!!errors.fields()['username_or_email'] || null"
          />
          @if (errors.fields()['username_or_email']; as message) {
            <p class="field-error">{{ message }}</p>
          }
        </div>
        <div>
          <div class="mb-1.5 flex items-center justify-between">
            <label class="label mb-0" for="login-password">{{ 'passwordLabel' | transloco }}</label>
            <a
              routerLink="/forgot-password"
              class="text-xs font-semibold text-primary hover:underline"
            >
              {{ 'forgotPasswordAction' | transloco }}
            </a>
          </div>
          <app-password-input
            inputId="login-password"
            formControlName="password"
            [invalid]="!!errors.fields()['password']"
          />
          @if (errors.fields()['password']; as message) {
            <p class="field-error">{{ message }}</p>
          }
        </div>
        <button
          type="submit"
          class="btn btn-primary btn-lg w-full"
          [disabled]="submitting() || form.invalid"
        >
          @if (submitting()) {
            <app-spinner />
          }
          {{ 'loginAction' | transloco }}
        </button>
      </form>

      <div class="my-6 flex items-center gap-3 text-xs text-fg-muted">
        <span class="h-px flex-1 bg-border"></span>
        {{ 'orDividerLabel' | transloco }}
        <span class="h-px flex-1 bg-border"></span>
      </div>
      @if (googleError()) {
        <p class="field-error mb-3 text-center">{{ googleError() }}</p>
      }
      <app-google-button [busy]="googleBusy()" />

      <p class="mt-8 text-center text-sm text-fg-muted">
        {{ 'webNoAccount' | transloco }}
        <a routerLink="/register" class="font-semibold text-primary hover:underline">
          {{ 'createAccountAction' | transloco }}
        </a>
      </p>
    </app-auth-layout>
  `,
})
export class LoginPage {
  /** Where the user was going before being asked to sign in. */
  readonly from = input<string>();

  private readonly api = inject(AuthApi);
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);
  private readonly errorText = inject(ErrorText);

  protected readonly form = inject(NonNullableFormBuilder).group({
    usernameOrEmail: ['', Validators.required],
    password: ['', Validators.required],
  });
  protected readonly submitting = signal(false);
  protected readonly errors = new FormErrors();
  protected readonly googleBusy = signal(false);
  protected readonly googleError = signal<string | null>(null);

  constructor() {
    inject(GoogleIdentity)
      .credentials.pipe(takeUntilDestroyed(inject(DestroyRef)))
      .subscribe((idToken) => void this.continueWithGoogle(idToken));
  }

  protected async submit(): Promise<void> {
    if (this.form.invalid || this.submitting()) return;
    this.submitting.set(true);
    this.errors.clear();
    const { usernameOrEmail, password } = this.form.getRawValue();
    try {
      await this.session.completeSignIn(await this.api.login(usernameOrEmail.trim(), password));
      await this.router.navigateByUrl(afterSignIn(this.router, this.from()));
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.submitting.set(false);
    }
  }

  private async continueWithGoogle(idToken: string): Promise<void> {
    this.googleBusy.set(true);
    this.googleError.set(null);
    try {
      const outcome = await this.api.googleVerify(idToken);
      if (outcome.status === 'authenticated') {
        await this.session.completeSignIn(outcome);
        await this.router.navigateByUrl(afterSignIn(this.router, this.from()));
      } else {
        this.session.requireGoogleCompletion(outcome);
        await this.router.navigateByUrl('/register/google-completion');
      }
    } catch (error) {
      this.googleError.set(this.errorText.message(error));
    } finally {
      this.googleBusy.set(false);
    }
  }
}
