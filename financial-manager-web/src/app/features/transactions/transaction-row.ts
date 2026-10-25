import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { ArrowDownLeft, ArrowLeftRight, ArrowUpRight, SlidersHorizontal } from 'lucide';

import { AppDatePipe, JoinPartsPipe, MoneyPipe } from '../../core/formatting/pipes';
import { Icon } from '../../shared/ui/icon';
import { MediaSrc } from '../../shared/ui/media-src';
import { CategoriesStore } from '../categories/categories.store';
import { WalletsStore } from '../wallets/wallets.store';
import { Transaction, isCredit, kindLabelKey } from './transaction.model';

/**
 * One operation in a list (plan.md sections 6.6, 7.5, 7.9): image or
 * direction icon, title, category (or kind) with time, signed amount.
 * Direction is shown by icon, sign and colour together, never colour alone
 * (section 6.7).
 */
@Component({
  selector: 'app-transaction-row',
  imports: [AppDatePipe, Icon, JoinPartsPipe, MediaSrc, MoneyPipe, RouterLink, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <a
      [routerLink]="['/app/transactions', transaction().id]"
      class="list-row group"
      [class.bg-primary-soft]="current()"
      [class.pointer-events-none]="current()"
    >
      @if (transaction().media_id) {
        <img
          [appMediaSrc]="transaction().media_id"
          alt=""
          class="h-10 w-10 shrink-0 rounded-xl bg-surface-2 object-cover"
        />
      } @else {
        <span
          class="grid h-10 w-10 shrink-0 place-items-center rounded-xl"
          [class]="credit() ? 'bg-credit/12 text-credit' : 'bg-debit/12 text-debit'"
        >
          <app-icon [icon]="icon()" [size]="18" />
        </span>
      }
      <span class="min-w-0 flex-1">
        <span class="block truncate text-sm font-medium text-fg">{{ transaction().title }}</span>
        <span class="mt-0.5 block truncate text-xs text-fg-muted">
          @let kind = kindKey();
          {{
            [
              kind ? (kind | transloco) : category(),
              showWallet() ? wallet() : null,
              transaction().occurred_at | appDate: (showDate() ? 'dateTime' : 'time'),
            ] | joinParts
          }}
        </span>
      </span>
      <span
        class="tabular shrink-0 text-sm font-semibold"
        [class]="credit() ? 'text-credit' : 'text-fg'"
      >
        {{ credit() ? '+' : '−' }}{{ transaction().amount_minor | money: transaction().currency }}
      </span>
    </a>
  `,
})
export class TransactionRow {
  readonly transaction = input.required<Transaction>();
  /** Full date instead of the time alone (lists not grouped by day). */
  readonly showDate = input(false);
  readonly showWallet = input(false);
  /** Marks the operation being viewed (in its payment group). */
  readonly current = input(false);

  private readonly categories = inject(CategoriesStore);
  private readonly wallets = inject(WalletsStore);

  protected readonly credit = computed(() => isCredit(this.transaction()));
  protected readonly kindKey = computed(() => kindLabelKey(this.transaction().kind));
  protected readonly category = computed(() =>
    this.categories.name(this.transaction().category_id),
  );
  protected readonly wallet = computed(() => this.wallets.byId(this.transaction().wallet_id)?.name);
  protected readonly icon = computed(() => {
    const t = this.transaction();
    if (t.kind === 'TRANSFER') return ArrowLeftRight;
    if (t.kind !== 'STANDARD') return SlidersHorizontal;
    return isCredit(t) ? ArrowDownLeft : ArrowUpRight;
  });
}
