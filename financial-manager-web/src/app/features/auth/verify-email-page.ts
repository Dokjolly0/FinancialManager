import { ChangeDetectionStrategy, Component, OnInit, inject, input, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { CircleAlert, CircleCheck } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { SessionService } from '../../core/session/session.service';
import { Toasts } from '../../shared/ui/toast';
import { Icon } from '../../shared/ui/icon';
import { Spinner } from '../../shared/ui/states';
import { AuthApi } from './auth.api';
import { AuthLayout } from './auth-layout';

/**
 * Opened by the link in the verification email, signed in or not. Confirms
 * the address as soon as it opens; if the link is used or expired, a
 * signed-in user can ask for a new one.
 */
@Component({
  selector: 'app-verify-email-page',
  imports: [AuthLayout, Icon, RouterLink, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-auth-layout [heading]="'verifyEmailScreenTitle' | transloco">
      <div class="card card-pad text-center">
        @switch (state()) {
          @case ('verifying') {
            <app-spinner [size]="28" class="mb-3 text-primary" />
            <p class="text-sm text-fg">{{ 'verifyEmailInProgressMessage' | transloco }}</p>
          }
          @case ('verified') {
            <app-icon [icon]="CircleCheck" [size]="36" class="mx-auto mb-3 text-credit" />
            <p class="text-sm text-fg">{{ 'verifyEmailSuccessMessage' | transloco }}</p>
          }
          @default {
            <app-icon [icon]="CircleAlert" [size]="36" class="mx-auto mb-3 text-debit" />
            <p class="text-sm text-fg">{{ failure() }}</p>
            @if (signedIn) {
              @if (resent()) {
                <p class="hint mt-4">{{ 'verificationResentMessage' | transloco }}</p>
              } @else {
                <button
                  type="button"
                  class="btn btn-outline mt-4"
                  [disabled]="resending()"
                  (click)="resend()"
                >
                  @if (resending()) {
                    <app-spinner />
                  }
                  {{ 'resendVerificationAction' | transloco }}
                </button>
              }
            }
          }
        }
        @if (state() !== 'verifying') {
          <div class="mt-5">
            <a [routerLink]="signedIn ? '/app/home' : '/login'" class="btn btn-primary">
              {{ 'goToAppAction' | transloco }}
            </a>
          </div>
        }
      </div>
    </app-auth-layout>
  `,
})
export class VerifyEmailPage implements OnInit {
  readonly token = input<string>();

  private readonly api = inject(AuthApi);
  private readonly session = inject(SessionService);
  private readonly errors = inject(ErrorText);
  private readonly toasts = inject(Toasts);

  protected readonly CircleCheck = CircleCheck;
  protected readonly CircleAlert = CircleAlert;
  protected readonly signedIn = this.session.status() === 'authenticated';
  protected readonly state = signal<'verifying' | 'verified' | 'failed'>('verifying');
  protected readonly failure = signal('');
  protected readonly resending = signal(false);
  protected readonly resent = signal(false);

  async ngOnInit(): Promise<void> {
    const token = this.token();
    if (!token) {
      this.fail(this.errors.code('INVALID_OR_EXPIRED_TOKEN'));
      return;
    }
    try {
      await this.api.verifyEmail(token);
      this.state.set('verified');
      if (this.signedIn) void this.session.reloadProfile().catch(() => undefined);
    } catch (error) {
      this.fail(this.errors.message(error));
    }
  }

  protected async resend(): Promise<void> {
    this.resending.set(true);
    try {
      await this.api.resendVerification();
      this.resent.set(true);
    } catch (error) {
      this.toasts.error(this.errors.message(error));
    } finally {
      this.resending.set(false);
    }
  }

  private fail(message: string): void {
    this.failure.set(message);
    this.state.set('failed');
  }
}
