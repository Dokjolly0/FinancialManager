import { NgTemplateOutlet } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  computed,
  inject,
  input,
  resource,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { CalendarX2, Minus, Plus, Ticket } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { AppDatePipe, MoneyPipe } from '../../core/formatting/pipes';
import { Ledger } from '../../core/state/ledger';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, SkeletonList } from '../../shared/ui/states';
import { WalletDialogs } from './wallet-dialogs';
import { VOUCHER_EXPIRING_SOON_DAYS, VoucherLot } from './wallet.model';
import { WalletsApi } from './wallets.api';

/**
 * Lots of a meal-voucher wallet: expiring soon, active, expired (the
 * backend writes expired vouchers off by itself). Lots are ledger-backed,
 * so this page only reads them; adding or removing vouchers goes through
 * the voucher credit dialog.
 */
@Component({
  selector: 'app-voucher-lots-page',
  imports: [
    AppDatePipe,
    Icon,
    NgTemplateOutlet,
    InlineError,
    MoneyPipe,
    PageHeader,
    RouterLink,
    SkeletonList,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'voucherLotsScreenTitle' | transloco"
        [subtitle]="data.value()?.wallet?.name"
        [back]="['/app/account/wallets', id(), 'edit']"
        [backLabel]="'backAction' | transloco"
      >
        <button
          type="button"
          class="btn btn-outline"
          [disabled]="!data.value()"
          (click)="credit(false)"
        >
          <app-icon [icon]="icons.Minus" [size]="18" /> {{ 'removeVouchersAction' | transloco }}
        </button>
        <button
          type="button"
          class="btn btn-primary"
          [disabled]="!data.value()"
          (click)="credit(true)"
        >
          <app-icon [icon]="icons.Plus" [size]="18" /> {{ 'addVouchersAction' | transloco }}
        </button>
      </app-page-header>

      @if (data.isLoading() && !data.hasValue()) {
        <div class="card overflow-hidden"><app-skeleton-list [rows]="4" /></div>
      } @else if (data.error()) {
        <div class="card">
          <app-inline-error [message]="errorText.message(data.error())" (retry)="data.reload()" />
        </div>
      } @else if (data.value(); as d) {
        <div class="card card-pad mb-6 flex items-center justify-between">
          <span class="text-sm text-fg-muted">{{
            'currentBalanceLabel'
              | transloco: { balance: (d.wallet.current_balance_minor | money: d.wallet.currency) }
          }}</span>
          <span class="text-sm font-semibold text-fg"
            >{{ 'voucherUnitValueLabel' | transloco }}:
            {{ d.wallet.voucher_unit_value_minor ?? 0 | money }}</span
          >
        </div>

        @if (groups().expiringSoon.length) {
          <h2 class="section-title mb-2 text-warning!">
            {{ 'voucherExpiringSoonSectionTitle' | transloco }}
          </h2>
          <div class="card mb-6 divide-y divide-border overflow-hidden border-warning/40">
            @for (lot of groups().expiringSoon; track lot.id) {
              <ng-container *ngTemplateOutlet="row; context: { lot, expired: false }" />
            }
          </div>
        }

        <h2 class="section-title mb-2">{{ 'voucherActiveSectionTitle' | transloco }}</h2>
        <div class="card mb-6 divide-y divide-border overflow-hidden">
          @for (lot of groups().active; track lot.id) {
            <ng-container *ngTemplateOutlet="row; context: { lot, expired: false }" />
          } @empty {
            <p class="px-4 py-4 text-sm text-fg-muted">
              {{ 'voucherActiveEmptyMessage' | transloco }}
            </p>
          }
        </div>

        <h2 class="section-title mb-2">{{ 'voucherExpiredSectionTitle' | transloco }}</h2>
        <div class="card divide-y divide-border overflow-hidden">
          @for (lot of groups().expired; track lot.id) {
            <ng-container *ngTemplateOutlet="row; context: { lot, expired: true }" />
          } @empty {
            <p class="px-4 py-4 text-sm text-fg-muted">
              {{ 'voucherExpiredEmptyMessage' | transloco }}
            </p>
          }
        </div>

        <ng-template #row let-lot="lot" let-expired="expired">
          @let quantity = expired ? lot.quantity_expired : lot.quantity_remaining;
          @if (expired && lot.expired_by_transaction_id) {
            <a class="list-row" [routerLink]="['/app/transactions', lot.expired_by_transaction_id]">
              <ng-container
                *ngTemplateOutlet="
                  rowContent;
                  context: { lot, expired, quantity, unit: d.wallet.voucher_unit_value_minor ?? 0 }
                "
              />
            </a>
          } @else {
            <div class="list-row hover:bg-transparent">
              <ng-container
                *ngTemplateOutlet="
                  rowContent;
                  context: { lot, expired, quantity, unit: d.wallet.voucher_unit_value_minor ?? 0 }
                "
              />
            </div>
          }
        </ng-template>
        <ng-template
          #rowContent
          let-lot="lot"
          let-expired="expired"
          let-quantity="quantity"
          let-unit="unit"
        >
          <span
            class="grid h-9 w-9 place-items-center rounded-lg"
            [class]="expired ? 'bg-debit/12 text-debit' : 'bg-primary-soft text-primary'"
          >
            <app-icon [icon]="expired ? icons.CalendarX2 : icons.Ticket" [size]="18" />
          </span>
          <span class="flex-1">
            <span class="block text-sm font-medium text-fg">{{
              'voucherLotQuantityLabel' | transloco: { count: quantity }
            }}</span>
            <span class="block text-xs text-fg-muted">
              {{
                (expired ? 'voucherLotExpiredOnLabel' : 'voucherLotExpiresOnLabel')
                  | transloco: { date: (lot.expires_at | appDate: 'dateLong') }
              }}
            </span>
          </span>
          <span class="tabular text-sm font-semibold text-fg">{{
            quantity * unit | money: d.wallet.currency
          }}</span>
        </ng-template>
      }
    </div>
  `,
})
export class VoucherLotsPage {
  readonly id = input.required<string>();

  private readonly api = inject(WalletsApi);
  private readonly dialogs = inject(WalletDialogs);
  private readonly ledger = inject(Ledger);
  protected readonly errorText = inject(ErrorText);
  protected readonly icons = { CalendarX2, Minus, Plus, Ticket };

  protected readonly data = resource({
    params: () => ({ id: this.id(), revision: this.ledger.revision() }),
    loader: async ({ params }) => {
      const [wallet, lots] = await Promise.all([
        this.api.get(params.id),
        this.api.voucherLots(params.id),
      ]);
      return { wallet, lots };
    },
  });

  /** The app's bucketing: active by expiry, expiring within 30 days, expired newest first. */
  protected readonly groups = computed(() => {
    const lots: VoucherLot[] = this.data.value()?.lots ?? [];
    const soon = Date.now() + VOUCHER_EXPIRING_SOON_DAYS * 86_400_000;
    const active = lots
      .filter((lot) => lot.quantity_remaining > 0)
      .sort((a, b) => a.expires_at.localeCompare(b.expires_at));
    return {
      active,
      expiringSoon: active.filter((lot) => new Date(lot.expires_at).getTime() <= soon),
      expired: lots
        .filter((lot) => lot.quantity_expired > 0)
        .sort((a, b) => b.expires_at.localeCompare(a.expires_at)),
    };
  });

  protected credit(addition: boolean): void {
    const wallet = this.data.value()?.wallet;
    if (wallet) void this.dialogs.voucherCredit(addition, wallet);
  }
}
