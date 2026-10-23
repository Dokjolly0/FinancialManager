import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../core/errors/form-errors';
import { browserTimeZone } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { SessionService } from '../../core/session/session.service';
import { Avatar } from '../../shared/ui/avatar';
import { AmountInput } from '../../shared/ui/form-controls';
import { PasswordInput } from '../../shared/ui/password-input';
import { Spinner } from '../../shared/ui/states';
import { AVATAR_COLORS, AVATAR_TEXT_COLOR, AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';
import { profileLocale } from './profile-locale';

/**
 * Completes the registration after a Google sign-in with no account yet
 * (plan.md section 7.4): name and verified email come from Google, so only
 * username, avatar, opening balance and an optional local password are asked.
 */
@Component({
  selector: 'app-google-completion-page',
  imports: [
    AmountInput,
    AuthLayout,
    Avatar,
    PasswordInput,
    ReactiveFormsModule,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-auth-layout [heading]="'completeRegistrationScreenTitle' | transloco">
      @if (session.pendingGoogle(); as pending) {
        <form class="space-y-5" [formGroup]="form" (ngSubmit)="submit()" novalidate>
          <p class="text-sm text-fg-muted">
            {{ 'googleSignInConfirmedMessage' | transloco: { email: pending.email } }}
          </p>
          @if (errors.message()) {
            <div
              class="rounded-xl border border-debit/30 bg-debit/5 px-4 py-3 text-sm text-debit"
              role="alert"
            >
              {{ errors.message() }}
            </div>
          }
          <div class="flex items-center gap-4">
            <app-avatar
              [firstName]="pending.suggested_first_name"
              [lastName]="pending.suggested_last_name"
              [background]="values().avatarColor ?? avatarColors[0]"
              [foreground]="avatarTextColor"
              [size]="64"
            />
            <div>
              <p class="label">{{ 'backgroundColorLabel' | transloco }}</p>
              <div
                class="flex flex-wrap gap-2"
                role="radiogroup"
                [attr.aria-label]="'backgroundColorLabel' | transloco"
              >
                @for (color of avatarColors; track color) {
                  <button
                    type="button"
                    role="radio"
                    class="h-8 w-8 rounded-full ring-offset-2 ring-offset-bg"
                    [class.ring-2]="values().avatarColor === color"
                    [class.ring-fg]="values().avatarColor === color"
                    [style.background-color]="color"
                    [attr.aria-checked]="values().avatarColor === color"
                    [attr.aria-label]="color"
                    (click)="form.controls.avatarColor.setValue(color)"
                  ></button>
                }
              </div>
            </div>
          </div>
          <div>
            <label class="label" for="gc-username">{{ 'usernameLabel' | transloco }}</label>
            <input
              id="gc-username"
              class="input"
              formControlName="username"
              autocomplete="username"
              [attr.aria-invalid]="!!errors.fields()['username'] || null"
            />
            @if (errors.fields()['username']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          <div class="rounded-xl border border-border p-4">
            <p class="mb-3 text-xs leading-relaxed text-fg-muted">
              {{ 'localPasswordOptionalHint' | transloco }}
            </p>
            <div class="space-y-4">
              <div>
                <label class="label" for="gc-password">{{ 'passwordLabel' | transloco }}</label>
                <app-password-input
                  inputId="gc-password"
                  formControlName="password"
                  autocomplete="new-password"
                  [invalid]="!!errors.fields()['password']"
                />
                @if (errors.fields()['password']; as m) {
                  <p class="field-error">{{ m }}</p>
                }
              </div>
              <div>
                <label class="label" for="gc-confirm">{{
                  'confirmPasswordLabel' | transloco
                }}</label>
                <app-password-input
                  inputId="gc-confirm"
                  formControlName="confirmPassword"
                  autocomplete="new-password"
                  [invalid]="!!errors.fields()['confirm_password']"
                />
                @if (errors.fields()['confirm_password']; as m) {
                  <p class="field-error">{{ m }}</p>
                }
              </div>
            </div>
          </div>
          <div>
            <label class="label" for="gc-balance">{{ 'initialBalanceLabel' | transloco }}</label>
            <app-amount-input
              inputId="gc-balance"
              formControlName="initialBalance"
              [invalid]="!!errors.fields()['initial_balance_minor']"
            />
            @if (errors.fields()['initial_balance_minor']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          <label class="flex cursor-pointer items-start gap-3">
            <input type="checkbox" class="checkbox mt-0.5" formControlName="acceptedTerms" />
            <span class="text-sm text-fg">{{ 'acceptTermsLabel' | transloco }}</span>
          </label>
          @if (errors.fields()['accepted_terms']; as m) {
            <p class="field-error">{{ m }}</p>
          }
          <div class="flex items-center gap-3 pt-2">
            <button type="button" class="btn btn-ghost" (click)="cancel()">
              {{ 'backToLoginAction' | transloco }}
            </button>
            <button type="submit" class="btn btn-primary btn-lg ml-auto" [disabled]="submitting()">
              @if (submitting()) {
                <app-spinner />
              }
              {{ 'completeRegistrationAction' | transloco }}
            </button>
          </div>
        </form>
      }
    </app-auth-layout>
  `,
})
export class GoogleCompletionPage {
  protected readonly session = inject(SessionService);
  private readonly api = inject(AuthApi);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly avatarColors = AVATAR_COLORS;
  protected readonly avatarTextColor = AVATAR_TEXT_COLOR;
  protected readonly form = this.fb.group({
    username: [''],
    password: [''],
    confirmPassword: [''],
    avatarColor: [AVATAR_COLORS[0]],
    initialBalance: this.fb.control<number | null>(0),
    acceptedTerms: [false],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });
  protected readonly submitting = signal(false);
  protected readonly errors = new FormErrors();

  protected cancel(): void {
    this.session.cancelGoogleCompletion();
    void this.router.navigateByUrl('/login');
  }

  /** The app's GoogleCompletionController.submit checks, then the request. */
  protected async submit(): Promise<void> {
    const pending = this.session.pendingGoogle();
    if (!pending) return;
    const v = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (v.username.trim().length < 3) codes['username'] = 'USERNAME_LENGTH_INVALID';
    if (v.password) {
      if (v.password.length < 8) codes['password'] = 'PASSWORD_TOO_SHORT';
      if (v.password !== v.confirmPassword) codes['confirm_password'] = 'PASSWORDS_DO_NOT_MATCH';
    }
    if (v.initialBalance === null) codes['initial_balance_minor'] = 'INVALID_AMOUNT';
    if (!v.acceptedTerms) codes['accepted_terms'] = 'TERMS_NOT_ACCEPTED';
    if (!this.errors.check(codes)) return;

    this.submitting.set(true);
    try {
      const response = await this.api.completeGoogleRegistration({
        ticket: pending.ticket,
        username: v.username.trim(),
        password: v.password,
        confirm_password: v.confirmPassword,
        avatar_background_color: v.avatarColor,
        avatar_text_color: AVATAR_TEXT_COLOR,
        initial_balance_minor: v.initialBalance ?? 0,
        currency: 'EUR',
        timezone: browserTimeZone(),
        locale: profileLocale(this.locale.language()),
        accepted_terms: true,
      });
      await this.session.completeSignIn(response);
      await this.router.navigateByUrl('/app/home');
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.submitting.set(false);
    }
  }
}
