import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { MailWarning } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { SessionService } from '../../core/session/session.service';
import { Avatar } from '../../shared/ui/avatar';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AuthApi } from '../auth/auth.api';
import { AccountApi } from './account.api';

/** Profile (plan.md section 7.13): name; username and email shown, not editable here. */
@Component({
  selector: 'app-profile-page',
  imports: [Avatar, Icon, PageHeader, ReactiveFormsModule, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'accountProfileScreenTitle' | transloco"
        back="/app/account"
        [backLabel]="'backAction' | transloco"
      />
      @if (session.profile(); as profile) {
        <form class="card card-pad space-y-5" [formGroup]="form" (ngSubmit)="save()" novalidate>
          <div class="flex items-center gap-4">
            <app-avatar
              [firstName]="form.controls.firstName.value"
              [lastName]="form.controls.lastName.value"
              [background]="profile.avatar_background_color"
              [foreground]="profile.avatar_text_color"
              [size]="56"
            />
            <p class="text-sm text-fg-muted">&#64;{{ profile.username }}</p>
          </div>
          <div class="grid gap-5 sm:grid-cols-2">
            <div>
              <label class="label" for="pf-first">{{ 'firstNameLabel' | transloco }}</label>
              <input
                id="pf-first"
                class="input"
                formControlName="firstName"
                autocomplete="given-name"
                [attr.aria-invalid]="!!errors.fields()['first_name'] || null"
              />
              @if (errors.fields()['first_name']; as m) {
                <p class="field-error">{{ m }}</p>
              }
            </div>
            <div>
              <label class="label" for="pf-last">{{ 'lastNameLabel' | transloco }}</label>
              <input
                id="pf-last"
                class="input"
                formControlName="lastName"
                autocomplete="family-name"
                [attr.aria-invalid]="!!errors.fields()['last_name'] || null"
              />
              @if (errors.fields()['last_name']; as m) {
                <p class="field-error">{{ m }}</p>
              }
            </div>
          </div>
          <div>
            <label class="label" for="pf-username">{{ 'usernameLabel' | transloco }}</label>
            <input id="pf-username" class="input" [value]="profile.username" disabled />
          </div>
          <div>
            <label class="label" for="pf-email">{{ 'emailLabel' | transloco }}</label>
            <input id="pf-email" class="input" [value]="profile.email" disabled />
            @if (!profile.email_verified) {
              <div
                class="mt-2 flex flex-wrap items-center gap-3 rounded-xl bg-warning/10 px-3 py-2 text-sm text-warning"
              >
                <app-icon [icon]="MailWarning" [size]="16" />
                <span class="flex-1">{{ 'webEmailNotVerified' | transloco }}</span>
                <button
                  type="button"
                  class="btn btn-ghost btn-sm"
                  [disabled]="resending()"
                  (click)="resend()"
                >
                  @if (resending()) {
                    <app-spinner />
                  }
                  {{ 'resendVerificationTooltip' | transloco }}
                </button>
              </div>
            }
          </div>
          @if (errors.message()) {
            <p class="field-error" role="alert">{{ errors.message() }}</p>
          }
          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary" [disabled]="saving() || form.pristine">
              @if (saving()) {
                <app-spinner />
              }
              {{ 'commonSave' | transloco }}
            </button>
          </div>
        </form>
      }
    </div>
  `,
})
export class ProfilePage {
  protected readonly session = inject(SessionService);
  private readonly account = inject(AccountApi);
  private readonly auth = inject(AuthApi);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly MailWarning = MailWarning;
  protected readonly form = inject(NonNullableFormBuilder).group({
    firstName: [this.session.profile()?.first_name ?? ''],
    lastName: [this.session.profile()?.last_name ?? ''],
  });
  protected readonly saving = signal(false);
  protected readonly resending = signal(false);
  protected readonly errors = new FormErrors();

  protected async save(): Promise<void> {
    const { firstName, lastName } = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (!firstName.trim()) codes['first_name'] = 'REQUIRED_FIELD';
    if (!lastName.trim()) codes['last_name'] = 'REQUIRED_FIELD';
    if (!this.errors.check(codes)) return;
    this.saving.set(true);
    try {
      await this.account.updateProfile({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
      });
      this.form.markAsPristine();
      this.toasts.success(this.transloco.translate('webSaved'));
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }

  protected async resend(): Promise<void> {
    this.resending.set(true);
    try {
      await this.auth.resendVerification();
      this.toasts.success(this.transloco.translate('verificationResentMessage'));
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.resending.set(false);
    }
  }
}
