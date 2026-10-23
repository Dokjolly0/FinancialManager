import { ChangeDetectionStrategy, Component, computed, inject, resource } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { ArrowDownLeft, ArrowRight, ArrowUpRight, Eye, EyeOff, Plus, Scale } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { AppDatePipe, MoneyPipe } from '../../core/formatting/pipes';
import { SessionService } from '../../core/session/session.service';
import { Ledger } from '../../core/state/ledger';
import { Icon } from '../../shared/ui/icon';
import { EmptyState, InlineError, SkeletonList } from '../../shared/ui/states';
import { ReportsApi } from '../reports/reports.api';
import { TransactionRow } from '../transactions/transaction-row';
import { TransactionsApi } from '../transactions/transactions.api';
import { WalletBadge } from '../wallets/wallet-badge';
import { WalletsStore } from '../wallets/wallets.store';
import { BalancePrivacy } from './balance-privacy';

/**
 * Home (plan.md section 7.5): total balance (maskable), this month's
 * income, expenses and net, the wallets, the latest operations.
 */
@Component({
  selector: 'app-home-page',
  imports: [
    AppDatePipe,
    EmptyState,
    Icon,
    InlineError,
    MoneyPipe,
    RouterLink,
    SkeletonList,
    TransactionRow,
    TranslocoPipe,
    WalletBadge,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './home-page.html',
})
export class HomePage {
  protected readonly session = inject(SessionService);
  protected readonly wallets = inject(WalletsStore);
  protected readonly privacy = inject(BalancePrivacy);
  private readonly ledger = inject(Ledger);
  private readonly transactionsApi = inject(TransactionsApi);
  private readonly reportsApi = inject(ReportsApi);
  private readonly errors = inject(ErrorText);

  protected readonly icons = { ArrowDownLeft, ArrowRight, ArrowUpRight, Eye, EyeOff, Plus, Scale };
  protected readonly today = new Date();

  protected readonly recent = resource({
    params: () => ({ revision: this.ledger.revision() }),
    loader: () => this.transactionsApi.list({ limit: 8 }).then((page) => page.transactions ?? []),
  });

  protected readonly month = resource({
    params: () => ({ revision: this.ledger.revision() }),
    loader: () => this.reportsApi.summary({ preset: 'current_month' }),
  });

  protected readonly recentError = computed(() =>
    this.recent.error() ? this.errors.message(this.recent.error()) : null,
  );
}
