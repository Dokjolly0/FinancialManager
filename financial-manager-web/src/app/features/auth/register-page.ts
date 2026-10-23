import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { Check } from 'lucide';

import { FormErrors } from '../../core/errors/form-errors';
import { browserTimeZone } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { MoneyPipe } from '../../core/formatting/pipes';
import { SessionService } from '../../core/session/session.service';
import { Avatar } from '../../shared/ui/avatar';
import { AmountInput } from '../../shared/ui/form-controls';
import { Icon } from '../../shared/ui/icon';
import { PasswordInput } from '../../shared/ui/password-input';
import { Spinner } from '../../shared/ui/states';
import { AVATAR_COLORS, AVATAR_TEXT_COLOR, AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';
import { profileLocale } from './profile-locale';

const ACCOUNT_FIELDS = [
  'first_name',
  'last_name',
  'username',
  'email',
  'password',
  'confirm_password',
];

/**
 * Registration (plan.md section 7.3) in three steps instead of one long
 * form: account, profile (avatar colour), wallet (opening balance, terms,
 * summary). Client checks mirror the backend's rules so most mistakes are
 * caught before sending; a server error on an account field goes back to
 * the first step.
 */
@Component({
  selector: 'app-register-page',
  imports: [
    AmountInput,
    AuthLayout,
    Avatar,
    Icon,
    MoneyPipe,
    PasswordInput,
    ReactiveFormsModule,
    RouterLink,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './register-page.html',
})
export class RegisterPage {
  private readonly api = inject(AuthApi);
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);
  private readonly locale = inject(LocaleService);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly steps = ['accountStepTitle', 'profileStepTitle', 'walletStepTitle'];
  protected readonly avatarColors = AVATAR_COLORS;
  protected readonly avatarTextColor = AVATAR_TEXT_COLOR;
  protected readonly Check = Check;

  protected readonly form = this.fb.group({
    firstName: [''],
    lastName: [''],
    username: [''],
    email: [''],
    password: [''],
    confirmPassword: [''],
    avatarColor: [AVATAR_COLORS[0]],
    initialBalance: this.fb.control<number | null>(0),
    acceptedTerms: [false],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  protected readonly step = signal(0);
  protected readonly submitting = signal(false);
  protected readonly errors = new FormErrors();

  protected next(): void {
    if (this.step() === 0 && !this.errors.check(this.validateAccount())) return;
    this.step.update((step) => Math.min(step + 1, 2));
  }

  protected back(): void {
    this.step.update((step) => Math.max(step - 1, 0));
  }

  /** The app's validateAccountStep: field values are error codes. */
  private validateAccount(): Record<string, string> {
    const v = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (!v.firstName.trim()) codes['first_name'] = 'REQUIRED_FIELD';
    if (!v.lastName.trim()) codes['last_name'] = 'REQUIRED_FIELD';
    if (v.username.trim().length < 3) codes['username'] = 'USERNAME_LENGTH_INVALID';
    if (!v.email.includes('@')) codes['email'] = 'INVALID_EMAIL';
    if (v.password.length < 8) codes['password'] = 'PASSWORD_TOO_SHORT';
    if (v.password !== v.confirmPassword) codes['confirm_password'] = 'PASSWORDS_DO_NOT_MATCH';
    return codes;
  }

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    if (v.initialBalance === null) {
      this.errors.check({ initial_balance_minor: 'INVALID_AMOUNT' });
      return;
    }
    if (!v.acceptedTerms) {
      this.errors.check({ accepted_terms: 'TERMS_NOT_ACCEPTED' });
      return;
    }
    this.submitting.set(true);
    this.errors.clear();
    try {
      const response = await this.api.register({
        first_name: v.firstName.trim(),
        last_name: v.lastName.trim(),
        username: v.username.trim(),
        email: v.email.trim(),
        password: v.password,
        confirm_password: v.confirmPassword,
        avatar_background_color: v.avatarColor,
        avatar_text_color: AVATAR_TEXT_COLOR,
        initial_balance_minor: v.initialBalance,
        currency: 'EUR',
        timezone: browserTimeZone(),
        locale: profileLocale(this.locale.language()),
        accepted_terms: true,
      });
      await this.session.completeSignIn(response);
      await this.router.navigateByUrl('/app/home');
    } catch (error) {
      this.errors.fromError(error);
      if (this.errors.fieldNames().some((field) => ACCOUNT_FIELDS.includes(field))) {
        this.step.set(0);
      }
    } finally {
      this.submitting.set(false);
    }
  }
}
