import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { ArrowLeftRight, ChevronRight, Plus, TicketPlus, TriangleAlert } from 'lucide';

import { MoneyPipe } from '../../core/formatting/pipes';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, SkeletonList } from '../../shared/ui/states';
import { BalancePrivacy } from '../home/balance-privacy';
import { WalletBadge } from './wallet-badge';
import { WalletDialogs } from './wallet-dialogs';
import { isMealVoucher } from './wallet.model';
import { WalletsStore } from './wallets.store';

/**
 * Wallets (plan.md multi-wallet extension): the total, the active wallets
 * (archived ones drop off, their history stays in reports and exports),
 * transfer and meal-voucher shortcuts.
 */
@Component({
  selector: 'app-wallets-page',
  imports: [
    EmptyState,
    Icon,
    InlineError,
    MoneyPipe,
    PageHeader,
    RouterLink,
    SkeletonList,
    TranslocoPipe,
    WalletBadge,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-page-header
      [title]="'walletsScreenTitle' | transloco"
      [subtitle]="'accountWalletsMenuSubtitle' | transloco"
    >
      @if (store.hasVoucherWallet()) {
        <button type="button" class="btn btn-outline" (click)="dialogs.voucherCredit(true)">
          <app-icon [icon]="icons.TicketPlus" [size]="18" />
          <span class="max-sm:hidden">{{ 'webAddVoucherCredit' | transloco }}</span>
        </button>
      }
      @if (store.hasMultipleWallets()) {
        <button type="button" class="btn btn-outline" (click)="dialogs.transfer()">
          <app-icon [icon]="icons.ArrowLeftRight" [size]="18" />
          <span class="max-sm:hidden">{{ 'transferAction' | transloco }}</span>
        </button>
      }
      <a routerLink="/app/account/wallets/new" class="btn btn-primary">
        <app-icon [icon]="icons.Plus" [size]="18" />
        {{ 'addWalletAction' | transloco }}
      </a>
    </app-page-header>

    @if (store.loading()) {
      <div class="card overflow-hidden"><app-skeleton-list [rows]="3" /></div>
    } @else if (store.error() && !store.loaded()) {
      <div class="card">
        <app-inline-error [message]="'walletsLoadError' | transloco" (retry)="store.reload()" />
      </div>
    } @else if (store.wallets().length === 0) {
      <div class="card"><app-empty-state [message]="'walletsEmptyStateMessage' | transloco" /></div>
    } @else {
      <div class="card card-pad mb-6 flex flex-wrap items-end justify-between gap-2">
        <div>
          <p class="text-sm text-fg-muted">{{ 'walletsTotalBalanceLabel' | transloco }}</p>
          <p class="tabular mt-1 text-3xl font-bold tracking-tight text-fg">
            {{ privacy.hidden() ? '••••••' : (store.totalMinor() | money: store.currency()) }}
          </p>
        </div>
        <p class="text-sm text-fg-muted">
          {{ 'webWalletCount' | transloco: { count: store.wallets().length } }}
        </p>
      </div>

      <div class="grid gap-3 md:grid-cols-2">
        @for (wallet of store.wallets(); track wallet.id) {
          <a
            [routerLink]="[wallet.id, 'edit']"
            class="card group flex items-center gap-4 p-4 transition-shadow hover:shadow-pop"
          >
            <app-wallet-badge [icon]="wallet.icon" [color]="wallet.color" [size]="48" />
            <span class="min-w-0 flex-1">
              <span class="block truncate font-semibold text-fg">{{ wallet.name }}</span>
              <span class="block text-xs text-fg-muted">{{
                typeKey(wallet.type) | transloco
              }}</span>
              @if ((wallet.voucher_expiring_soon_count ?? 0) > 0) {
                <span class="badge mt-1.5 bg-warning/12 text-warning">
                  <app-icon [icon]="icons.TriangleAlert" [size]="12" />
                  {{
                    'voucherExpiringSoonBadge'
                      | transloco: { count: wallet.voucher_expiring_soon_count }
                  }}
                </span>
              }
            </span>
            <span class="tabular text-right text-lg font-semibold text-fg">
              {{
                privacy.hidden() ? '••••' : (wallet.current_balance_minor | money: wallet.currency)
              }}
            </span>
            <app-icon
              [icon]="icons.ChevronRight"
              [size]="18"
              class="text-fg-muted transition-transform group-hover:translate-x-0.5"
            />
          </a>
        }
      </div>
    }
  `,
})
export class WalletsPage {
  protected readonly store = inject(WalletsStore);
  protected readonly dialogs = inject(WalletDialogs);
  protected readonly privacy = inject(BalancePrivacy);
  protected readonly icons = { ArrowLeftRight, ChevronRight, Plus, TicketPlus, TriangleAlert };
  protected readonly isMealVoucher = isMealVoucher;

  protected typeKey(type: string): string {
    return WALLET_TYPE_KEYS[type] ?? 'walletTypeOther';
  }
}

export const WALLET_TYPE_KEYS: Record<string, string> = {
  CASH: 'walletTypeCash',
  BANK: 'walletTypeBank',
  MEAL_VOUCHER: 'walletTypeMealVoucher',
  OTHER: 'walletTypeOther',
};
