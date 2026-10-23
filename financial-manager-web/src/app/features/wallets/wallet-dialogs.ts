import { Injectable, inject } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

import { Overlay } from '../../shared/ui/overlay';
import { Toasts } from '../../shared/ui/toast';
import type { AmountDateData } from '../transactions/dialogs/amount-date-dialog';
import { Transaction } from '../transactions/transaction.model';
import type { VoucherCreditData } from './dialogs/voucher-credit-dialog';
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
