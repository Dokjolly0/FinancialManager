import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';

import { ErrorText } from '../../core/errors/error-text';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { WalletBadge } from '../wallets/wallet-badge';
import { WALLET_PURPOSE_MAX_LENGTH, Wallet } from '../wallets/wallet.model';
import { WalletsApi } from '../wallets/wallets.api';
import { WalletsStore } from '../wallets/wallets.store';
import { AiApi } from './ai.api';

const SUGGESTIONS = [
  'aiPurposeSuggestionDaily',
  'aiPurposeSuggestionSavings',
  'aiPurposeSuggestionEmergency',
  'aiPurposeSuggestionHome',
  'aiPurposeSuggestionLeisure',
];

/**
 * What each wallet is for, read by the analysis (plan.md section 32.3):
 * one text per wallet with suggestions, saved on the wallet itself.
 */
@Component({
  selector: 'app-ai-wallet-purposes-page',
  imports: [EmptyState, PageHeader, Spinner, TranslocoPipe, WalletBadge],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'aiWalletPurposesMenuTitle' | transloco"
        [subtitle]="'aiWalletPurposesIntro' | transloco"
        back="/app/account/ai"
        [backLabel]="'backAction' | transloco"
      />
      <p class="mb-4 text-sm text-fg-muted">
        {{
          'aiWalletPurposesProgress' | transloco: { done: done(), total: wallets.wallets().length }
        }}
      </p>
      <div class="space-y-4">
        @for (wallet of wallets.wallets(); track wallet.id) {
          <section class="card card-pad">
            <div class="mb-3 flex items-center gap-3">
              <app-wallet-badge [icon]="wallet.icon" [color]="wallet.color" [size]="36" />
              <div class="min-w-0 flex-1">
                <p class="truncate font-semibold text-fg">{{ wallet.name }}</p>
                @if (!wallet.purpose) {
                  <p class="text-xs text-fg-muted">{{ 'aiWalletNoPurpose' | transloco }}</p>
                }
              </div>
            </div>
            <label class="sr-only" [for]="'purpose-' + wallet.id">{{
              'walletPurposeLabel' | transloco
            }}</label>
            <textarea
              class="input"
              rows="2"
              [id]="'purpose-' + wallet.id"
              [attr.maxlength]="maxLength"
              [placeholder]="'walletPurposeHint' | transloco"
              [value]="draft(wallet)"
              (input)="setDraft(wallet.id, $any($event.target).value)"
            ></textarea>
            <div class="mt-2 flex flex-wrap items-center gap-1.5">
              @for (key of suggestions; track key) {
                <button type="button" class="chip" (click)="suggest(wallet.id, key)">
                  {{ key | transloco }}
                </button>
              }
              <span class="flex-1"></span>
              <button
                type="button"
                class="btn btn-primary btn-sm"
                [disabled]="saving() === wallet.id || draft(wallet) === (wallet.purpose ?? '')"
                (click)="save(wallet)"
              >
                @if (saving() === wallet.id) {
                  <app-spinner />
                }
                {{ 'aiSavePurpose' | transloco }}
              </button>
            </div>
          </section>
        } @empty {
          <div class="card">
            <app-empty-state [message]="'aiWalletPurposesEmpty' | transloco" />
          </div>
        }
      </div>
    </div>
  `,
})
export class AiWalletPurposesPage {
  protected readonly wallets = inject(WalletsStore);
  private readonly walletsApi = inject(WalletsApi);
  private readonly ai = inject(AiApi);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly suggestions = SUGGESTIONS;
  protected readonly maxLength = WALLET_PURPOSE_MAX_LENGTH;
  private readonly drafts = signal<Record<string, string>>({});
  protected readonly saving = signal<string | null>(null);
  protected readonly done = computed(
    () => this.wallets.wallets().filter((w) => !!w.purpose).length,
  );

  protected draft(wallet: Wallet): string {
    return this.drafts()[wallet.id] ?? wallet.purpose ?? '';
  }

  protected suggest(id: string, key: string): void {
    this.setDraft(id, this.transloco.translate(key));
  }

  protected setDraft(id: string, value: string): void {
    this.drafts.update((drafts) => ({ ...drafts, [id]: value }));
  }

  protected async save(wallet: Wallet): Promise<void> {
    this.saving.set(wallet.id);
    try {
      await this.walletsApi.update(wallet.id, {
        name: wallet.name,
        type: wallet.type,
        icon: wallet.icon,
        color: wallet.color,
        purpose: this.draft(wallet).trim() || null,
        voucher_expiry_cutoff_month: wallet.voucher_expiry_cutoff_month ?? null,
        voucher_expiry_month: wallet.voucher_expiry_month ?? null,
        voucher_expiry_day: wallet.voucher_expiry_day ?? null,
        version: wallet.version,
      });
      this.drafts.update((drafts) => {
        const next = { ...drafts };
        delete next[wallet.id];
        return next;
      });
      this.ai.settings.reload();
      this.toasts.success(this.transloco.translate('webSaved'));
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.saving.set(null);
    }
  }
}
