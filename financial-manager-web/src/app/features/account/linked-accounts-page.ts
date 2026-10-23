import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  resource,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';

import { GoogleIdentity } from '../../core/auth/google-identity';
import { ErrorText } from '../../core/errors/error-text';
import { AppDatePipe } from '../../core/formatting/pipes';
import { GoogleButton } from '../../shared/ui/google-button';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AccountApi } from './account.api';
import { PasswordPromptData, PasswordPromptDialog } from './password-prompt-dialog';

/**
 * Linked accounts (plan.md sections 7.13, 15.3, 15.4): Google, linked with
 * Google's button and the current password, or unlinked (the backend
 * refuses when it is the only way to sign in).
 */
@Component({
  selector: 'app-linked-accounts-page',
  imports: [AppDatePipe, GoogleButton, InlineError, PageHeader, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'accountLinkedAccountsMenuTitle' | transloco"
        back="/app/account"
        [backLabel]="'backAction' | transloco"
      />
      <section class="card card-pad">
        @if (identities.isLoading() && !identities.hasValue()) {
          <div class="skeleton h-16 w-full"></div>
        } @else if (identities.error()) {
          <app-inline-error
            [message]="errorText.message(identities.error())"
            (retry)="identities.reload()"
          />
        } @else {
          <div class="flex flex-wrap items-center gap-4">
            <span
              class="grid h-12 w-12 place-items-center rounded-xl border border-border bg-white"
            >
              <svg viewBox="0 0 48 48" width="24" height="24" aria-hidden="true">
                <path
                  fill="#FFC107"
                  d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"
                />
                <path
                  fill="#FF3D00"
                  d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"
                />
                <path
                  fill="#4CAF50"
                  d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z"
                />
                <path
                  fill="#1976D2"
                  d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"
                />
              </svg>
            </span>
            <div class="min-w-0 flex-1">
              <p class="font-semibold text-fg">Google</p>
              @if (google(); as g) {
                <p class="text-sm text-fg-muted">
                  {{
                    g.last_used_at
                      ? ('lastUsedLabel'
                        | transloco: { date: (g.last_used_at | appDate: 'dateTime') })
                      : ('linkedNeverUsedLabel' | transloco)
                  }}
                </p>
              } @else {
                <p class="text-sm text-fg-muted">{{ 'notLinkedLabel' | transloco }}</p>
              }
            </div>
            @if (google()) {
              <button
                type="button"
                class="btn btn-danger-ghost"
                [disabled]="busy()"
                (click)="unlink()"
              >
                @if (busy()) {
                  <app-spinner />
                }
                {{ 'unlinkGoogleAction' | transloco }}
              </button>
            }
          </div>
          @if (!google()) {
            <div class="mt-5 border-t border-border pt-5">
              <p class="mb-3 text-sm text-fg-muted">{{ 'googleWebLinkDialogTitle' | transloco }}</p>
              <app-google-button [busy]="busy()" />
            </div>
          }
        }
      </section>
    </div>
  `,
})
export class LinkedAccountsPage {
  private readonly account = inject(AccountApi);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);

  protected readonly identities = resource({ loader: () => this.account.identities() });
  protected readonly google = computed(
    () => this.identities.value()?.find((identity) => identity.provider === 'google') ?? null,
  );
  protected readonly busy = signal(false);

  constructor() {
    // Google's button here links instead of signing in.
    inject(GoogleIdentity)
      .credentials.pipe(takeUntilDestroyed(inject(DestroyRef)))
      .subscribe((idToken) => void this.link(idToken));
  }

  private async link(idToken: string): Promise<void> {
    const password = await this.overlay.result<string, PasswordPromptData>(PasswordPromptDialog, {
      data: {
        title: this.transloco.translate('confirmPasswordDialogTitle'),
        label: this.transloco.translate('currentPasswordLabel'),
        confirmLabel: this.transloco.translate('commonContinue'),
      },
    });
    if (password === undefined) return;
    this.busy.set(true);
    try {
      await this.account.linkGoogle(idToken, password);
      this.toasts.success(this.transloco.translate('googleLinkedSuccessMessage'));
      this.identities.reload();
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.busy.set(false);
    }
  }

  protected async unlink(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('unlinkGoogleConfirmTitle'),
      message: this.transloco.translate('unlinkGoogleConfirmMessage'),
      confirmLabel: this.transloco.translate('unlinkGoogleAction'),
      destructive: true,
    });
    if (!confirmed) return;
    this.busy.set(true);
    try {
      await this.account.unlinkGoogle();
      this.toasts.success(this.transloco.translate('googleUnlinkedSuccessMessage'));
      this.identities.reload();
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.busy.set(false);
    }
  }
}
