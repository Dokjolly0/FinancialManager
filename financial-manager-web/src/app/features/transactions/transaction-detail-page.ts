import {
  ChangeDetectionStrategy,
  Component,
  computed,
  inject,
  input,
  resource,
  signal,
} from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Link, Link2Off, Pencil, Trash2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { AppDatePipe, MoneyPipe } from '../../core/formatting/pipes';
import { Ledger } from '../../core/state/ledger';
import { Icon } from '../../shared/ui/icon';
import { MediaSrc } from '../../shared/ui/media-src';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { CategoriesStore } from '../categories/categories.store';
import { WalletBadge } from '../wallets/wallet-badge';
import { WalletDialogs } from '../wallets/wallet-dialogs';
import { WalletsStore } from '../wallets/wallets.store';
import { TransactionRow } from './transaction-row';
import { Transaction, isCredit, isEditable } from './transaction.model';
import { TransactionsApi } from './transactions.api';

/**
 * Operation detail (plan.md section 7.10). Standard operations can be
 * edited, deleted and get a linked payment; meal-voucher expenses are edited
 * and deleted as a pair through their own form; opening balances and
 * transfers only get amount and date corrected; adjustments are read-only.
 * Operations in a payment group list every member with the group's total.
 */
@Component({
  selector: 'app-transaction-detail-page',
  imports: [
    AppDatePipe,
    Icon,
    InlineError,
    MediaSrc,
    MoneyPipe,
    PageHeader,
    RouterLink,
    Spinner,
    TransactionRow,
    TranslocoPipe,
    WalletBadge,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './transaction-detail-page.html',
})
export class TransactionDetailPage {
  readonly id = input.required<string>();

  private readonly api = inject(TransactionsApi);
  private readonly ledger = inject(Ledger);
  private readonly overlay = inject(Overlay);
  private readonly dialogs = inject(WalletDialogs);
  private readonly router = inject(Router);
  private readonly transloco = inject(TranslocoService);
  private readonly toasts = inject(Toasts);
  protected readonly errorText = inject(ErrorText);
  protected readonly wallets = inject(WalletsStore);
  protected readonly categories = inject(CategoriesStore);

  protected readonly icons = { Link, Link2Off, Pencil, Trash2 };
  protected readonly deleting = signal(false);

  protected readonly data = resource({
    params: () => ({ id: this.id(), revision: this.ledger.revision() }),
    loader: async ({ params }) => {
      const transaction = await this.api.get(params.id);
      const members = transaction.payment_group_id
        ? ((await this.api.list({ limit: 100, payment_group_id: transaction.payment_group_id }))
            .transactions ?? [])
        : [];
      return { transaction, members };
    },
  });

  protected readonly transaction = computed(() => this.data.value()?.transaction ?? null);
  protected readonly members = computed(() => this.data.value()?.members ?? []);
  protected readonly wallet = computed(() => this.wallets.byId(this.transaction()?.wallet_id));
  protected readonly credit = computed(() => {
    const t = this.transaction();
    return t ? isCredit(t) : false;
  });
  /** Signed sum of the group: credits add, debits subtract (the backend's SignedDelta). */
  protected readonly groupTotal = computed(() =>
    this.members().reduce((sum, m) => sum + (isCredit(m) ? m.amount_minor : -m.amount_minor), 0),
  );

  /** The app's rule: a standard row on a voucher wallet, or the shortfall leg linked to one. */
  protected readonly voucherExpense = computed(() => {
    const t = this.transaction();
    if (!t || t.kind !== 'STANDARD' || t.system_generated) return false;
    return !!t.linked_transaction_id || this.wallet()?.type === 'MEAL_VOUCHER';
  });
  protected readonly editable = computed(() => {
    const t = this.transaction();
    return !!t && !this.voucherExpense() && isEditable(t);
  });

  protected kindKey(t: Transaction): string {
    switch (t.kind) {
      case 'OPENING_BALANCE':
        return 'openingBalanceKindLabel';
      case 'BALANCE_ADJUSTMENT':
        return 'balanceAdjustmentKindLabel';
      case 'TRANSFER':
        return 'transferKindLabel';
      default:
        return 'manualKindLabel';
    }
  }

  protected async editAmountDate(): Promise<void> {
    const t = this.transaction();
    if (!t) return;
    await this.dialogs.editAmountDate(t, t.kind === 'TRANSFER' ? 'transfer' : 'opening-balance');
  }

  protected async editVoucherExpense(): Promise<void> {
    const t = this.transaction();
    if (t) await this.dialogs.editVoucherExpense(t);
  }

  protected async remove(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('deleteTransactionConfirmTitle'),
      message: this.transloco.translate('deleteTransactionConfirmMessage'),
      confirmLabel: this.transloco.translate('commonDelete'),
      destructive: true,
    });
    if (!confirmed) return;
    this.deleting.set(true);
    try {
      await this.api.delete(this.id());
      this.toasts.success(this.transloco.translate('webDeleted'));
      await this.router.navigateByUrl('/app/history');
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    } finally {
      this.deleting.set(false);
    }
  }

  protected async unlink(member: Transaction): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('webUnlinkPaymentTitle'),
      message: this.transloco.translate('webUnlinkPaymentMessage'),
      confirmLabel: this.transloco.translate('webUnlinkPaymentAction'),
    });
    if (!confirmed) return;
    try {
      await this.api.unlinkPaymentGroup(member.id);
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }
}
