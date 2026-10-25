import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';
import { Ban, KeyRound, Send, ShieldCheck, Undo2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Sheet, SheetFooter } from '../../shared/ui/sheet';
import { Spinner } from '../../shared/ui/states';
import { AiApi } from './ai.api';

/**
 * The cloud AI disclosure (plan.md section 32.2, the app's AiConsentSheet):
 * what is sent, what never is, the key, the provider, how to change your
 * mind. Accepting records the current consent version. Resolves true once
 * accepted.
 */
@Component({
  selector: 'app-ai-consent-dialog',
  imports: [Icon, Sheet, SheetFooter, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet [title]="'aiConsentTitle' | transloco">
      <p class="text-sm leading-relaxed text-fg-muted">{{ 'aiConsentIntro' | transloco }}</p>
      <div class="mt-5 space-y-4">
        <div class="flex gap-3">
          <app-icon [icon]="icons.Send" class="mt-0.5 text-primary" />
          <div>
            <h3 class="text-sm font-semibold text-fg">{{ 'aiConsentSentTitle' | transloco }}</h3>
            <ul class="mt-1 list-disc space-y-1 pl-4 text-sm text-fg-muted">
              <li>{{ 'aiConsentSentAggregates' | transloco }}</li>
              <li>{{ 'aiConsentSentWallets' | transloco }}</li>
              <li>{{ 'aiConsentSentTransactions' | transloco }}</li>
              <li>{{ 'aiConsentSentContext' | transloco }}</li>
            </ul>
          </div>
        </div>
        @for (item of items; track item.title) {
          <div class="flex gap-3">
            <app-icon [icon]="item.icon" class="mt-0.5 text-primary" />
            <div>
              <h3 class="text-sm font-semibold text-fg">{{ item.title | transloco }}</h3>
              <p class="mt-1 text-sm leading-relaxed text-fg-muted">{{ item.body | transloco }}</p>
            </div>
          </div>
        }
      </div>
      @if (error()) {
        <p class="field-error mt-4" role="alert">{{ error() }}</p>
      }
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close(false)">
          {{ 'aiConsentDecline' | transloco }}
        </button>
        <button type="button" class="btn btn-primary" [disabled]="saving()" (click)="accept()">
          @if (saving()) {
            <app-spinner />
          }
          {{ 'aiConsentAccept' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class AiConsentDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  private readonly version = inject<number>(DIALOG_DATA);
  private readonly ai = inject(AiApi);
  private readonly errors = inject(ErrorText);

  protected readonly icons = { Send };
  protected readonly items = [
    { title: 'aiConsentNeverTitle', body: 'aiConsentNeverBody', icon: Ban },
    { title: 'aiConsentKeyTitle', body: 'aiConsentKeyBody', icon: KeyRound },
    { title: 'aiConsentProviderTitle', body: 'aiConsentProviderBody', icon: ShieldCheck },
    { title: 'aiConsentRevokeTitle', body: 'aiConsentRevokeBody', icon: Undo2 },
  ];
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);

  protected async accept(): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.ai.acceptConsent(this.version);
      this.ref.close(true);
    } catch (error) {
      this.error.set(this.errors.message(error));
    } finally {
      this.saving.set(false);
    }
  }
}
