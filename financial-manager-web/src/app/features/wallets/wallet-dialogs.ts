import { Injectable, inject } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

import { Overlay } from '../../shared/ui/overlay';
import { Toasts } from '../../shared/ui/toast';
import type { AmountDateData } from '../transactions/dialogs/amount-date-dialog';
import { Transaction } from '../transactions/transaction.model';
import type { VoucherCreditData } from './dialogs/voucher-credit-dialog';
import type { VoucherExpenseData } from './dialogs/voucher-expense-dialog';
import { WalletsStore } from './wallets.store';
import { TransactionsApi } from '../transactions/transactions.api';
import { Wallet } from './wallet.model';

/**
 * Opens the wallet operations as drawers; each resolves true when something
 * was saved. The dialogs are lazy chunks: the shell's "Aggiungi" menu
 * reaches them, and they shouldn't weigh on the first load.
 */
@Injectable({ providedIn: 'root' })
export class WalletDialogs {
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly wallets = inject(WalletsStore);
  private readonly transactions = inject(TransactionsApi);

  async transfer(): Promise<boolean> {
    const { TransferDialog } = await import('./dialogs/transfer-dialog');
    return this.saved(this.overlay.result<boolean>(TransferDialog, { variant: 'drawer' }));
  }

  async adjustBalance(wallet: Wallet): Promise<boolean> {
    const { BalanceAdjustmentDialog } = await import('./dialogs/balance-adjustment-dialog');
    return this.saved(
      this.overlay.result<boolean, Wallet>(BalanceAdjustmentDialog, {
        variant: 'drawer',
        data: wallet,
      }),
    );
  }

  async voucherCredit(addition: boolean, wallet?: Wallet): Promise<boolean> {
    const { VoucherCreditDialog } = await import('./dialogs/voucher-credit-dialog');
    return this.saved(
      this.overlay.result<boolean, VoucherCreditData>(VoucherCreditDialog, {
        variant: 'drawer',
        data: { addition, wallet },
      }),
    );
  }

  async voucherExpense(data: VoucherExpenseData = {}): Promise<boolean> {
    const { VoucherExpenseDialog } = await import('./dialogs/voucher-expense-dialog');
    return this.saved(
      this.overlay.result<boolean, VoucherExpenseData>(VoucherExpenseDialog, {
        variant: 'drawer',
        data,
      }),
    );
  }

  /**
   * Edits a meal-voucher expense from either of its legs (the app's
   * TransactionDetailScreen): the voucher-wallet leg, and the shortfall leg
   * when there is one, linked to each other.
   */
  async editVoucherExpense(transaction: Transaction): Promise<boolean> {
    const onVoucherWallet = this.wallets.byId(transaction.wallet_id)?.type === 'MEAL_VOUCHER';
    const linked = transaction.linked_transaction_id
      ? await this.transactions.get(transaction.linked_transaction_id)
      : null;
    return this.voucherExpense(
      onVoucherWallet
        ? { voucherTransaction: transaction, otherTransaction: linked }
        : { voucherTransaction: linked ?? transaction, otherTransaction: transaction },
    );
  }

  async editAmountDate(transaction: Transaction, mode: AmountDateData['mode']): Promise<boolean> {
    const { AmountDateDialog } = await import('../transactions/dialogs/amount-date-dialog');
    return this.saved(
      this.overlay.result<boolean, AmountDateData>(AmountDateDialog, {
        variant: 'drawer',
        data: { transaction, mode },
      }),
    );
  }

  private async saved(result: Promise<boolean | undefined>): Promise<boolean> {
    const done = (await result) === true;
    if (done) this.toasts.success(this.transloco.translate('webSaved'));
    return done;
  }
}
