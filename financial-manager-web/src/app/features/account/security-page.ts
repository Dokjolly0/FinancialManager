import { ChangeDetectionStrategy, Component, inject, resource, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Laptop, Smartphone } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { AppDatePipe } from '../../core/formatting/pipes';
import { SessionService } from '../../core/session/session.service';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, SkeletonList, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { PasswordInput } from '../../shared/ui/password-input';
import { AccountApi, AccountSession } from './account.api';

/** Security (plan.md section 7.13): change password, active sessions with revoke, logout everywhere. */
@Component({
  selector: 'app-security-page',
  imports: [
    AppDatePipe,
    Icon,
    InlineError,
    PageHeader,
    PasswordInput,
    ReactiveFormsModule,
    SkeletonList,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'accountSecurityMenuTitle' | transloco"
        back="/app/account"
        [backLabel]="'backAction' | transloco"
      />

      <form
        class="card card-pad space-y-5"
        [formGroup]="form"
        (ngSubmit)="changePassword()"
        novalidate
      >
        <h2 class="font-semibold text-fg">{{ 'webChangePassword' | transloco }}</h2>
        <div>
          <label class="label" for="sec-current">{{ 'currentPasswordLabel' | transloco }}</label>
          <app-password-input
            inputId="sec-current"
            formControlName="current"
            [invalid]="!!errors.fields()['current_password']"
          />
          @if (errors.fields()['current_password']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div class="grid gap-5 sm:grid-cols-2">
          <div>
            <label class="label" for="sec-new">{{ 'newPasswordLabel' | transloco }}</label>
            <app-password-input
              inputId="sec-new"
              formControlName="next"
              autocomplete="new-password"
              [invalid]="!!errors.fields()['new_password']"
            />
            @if (errors.fields()['new_password']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          <div>
            <label class="label" for="sec-confirm">{{ 'webConfirmNewPassword' | transloco }}</label>
            <app-password-input
              inputId="sec-confirm"
              formControlName="confirm"
              autocomplete="new-password"
              [invalid]="!!errors.fields()['confirm_new_password']"
            />
            @if (errors.fields()['confirm_new_password']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
        <div class="flex justify-end">
          <button type="submit" class="btn btn-primary" [disabled]="saving()">
            @if (saving()) {
              <app-spinner />
            }
            {{ 'webUpdatePassword' | transloco }}
          </button>
        </div>
      </form>

      <section class="mt-8">
        <div class="mb-3 flex items-center justify-between">
          <h2 class="section-title">{{ 'webActiveSessions' | transloco }}</h2>
          <button type="button" class="btn btn-danger-ghost btn-sm" (click)="logoutAll()">
            {{ 'accountLogoutAllAction' | transloco }}
          </button>
        </div>
        <div class="card divide-y divide-border overflow-hidden">
          @if (sessions.isLoading() && !sessions.hasValue()) {
            <app-skeleton-list [rows]="3" />
          } @else if (sessions.error()) {
            <app-inline-error
              [message]="errorText.message(sessions.error())"
              (retry)="sessions.reload()"
            />
          } @else {
            @for (s of sessions.value(); track s.id) {
              <div class="flex items-center gap-3 px-4 py-3">
                <span
                  class="grid h-10 w-10 place-items-center rounded-xl bg-surface-2 text-fg-muted"
                >
                  <app-icon
                    [icon]="s.platform === 'web' ? icons.Laptop : icons.Smartphone"
                    [size]="18"
                  />
                </span>
                <span class="min-w-0 flex-1">
                  <span class="flex items-center gap-2">
                    <span class="truncate text-sm font-medium text-fg">{{
                      s.device_name || ('webUnknownDevice' | transloco)
                    }}</span>
                    @if (s.is_current) {
                      <span class="badge bg-primary-soft text-primary">{{
                        'webThisDevice' | transloco
                      }}</span>
                    }
                  </span>
                  <span class="block text-xs text-fg-muted">
                    {{
                      'webLastAccess' | transloco: { date: (s.last_used_at | appDate: 'dateTime') }
                    }}
                  </span>
                </span>
                @if (!s.is_current) {
                  <button
                    type="button"
                    class="btn btn-ghost btn-sm text-debit"
                    [disabled]="revoking() === s.id"
                    (click)="revoke(s)"
                  >
                    @if (revoking() === s.id) {
                      <app-spinner />
                    }
                    {{ 'webEndSession' | transloco }}
                  </button>
                }
              </div>
            }
          }
        </div>
      </section>
    </div>
  `,
})
export class SecurityPage {
  private readonly account = inject(AccountApi);
  private readonly session = inject(SessionService);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);
  protected readonly icons = { Laptop, Smartphone };

  protected readonly form = inject(NonNullableFormBuilder).group({
    current: [''],
    next: [''],
    confirm: [''],
  });
  protected readonly saving = signal(false);
  protected readonly revoking = signal<string | null>(null);
  protected readonly errors = new FormErrors();
  protected readonly sessions = resource({ loader: () => this.account.sessions() });

  protected async changePassword(): Promise<void> {
    const { current, next, confirm } = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (!current) codes['current_password'] = 'REQUIRED_FIELD';
    if (next.length < 8) codes['new_password'] = 'PASSWORD_TOO_SHORT';
    if (next !== confirm) codes['confirm_new_password'] = 'PASSWORDS_DO_NOT_MATCH';
    if (!this.errors.check(codes)) return;
    this.saving.set(true);
    try {
      await this.account.changePassword(current, next);
      this.form.reset();
      this.toasts.success(this.transloco.translate('webPasswordUpdated'));
      this.sessions.reload();
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }

  protected async revoke(s: AccountSession): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('webEndSessionTitle'),
      message: s.device_name ?? undefined,
      confirmLabel: this.transloco.translate('webEndSession'),
      destructive: true,
    });
    if (!confirmed) return;
    this.revoking.set(s.id);
    try {
      await this.account.revokeSession(s.id);
      this.sessions.reload();
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.revoking.set(null);
    }
  }

  protected async logoutAll(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('accountLogoutAllConfirmTitle'),
      message: this.transloco.translate('accountLogoutAllConfirmMessage'),
      confirmLabel: this.transloco.translate('accountLogoutAllAction'),
      destructive: true,
    });
    if (confirmed) await this.session.signOut(true);
  }
}
