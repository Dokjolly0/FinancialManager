import { Injectable, computed, inject } from '@angular/core';
import { Router } from '@angular/router';
import type { IconNode } from 'lucide';
import { ArrowLeftRight, ArrowUpDown, TicketPlus } from 'lucide';

import { WalletDialogs } from '../features/wallets/wallet-dialogs';
import { WalletsStore } from '../features/wallets/wallets.store';

export interface AddAction {
  id: string;
  labelKey: string;
  icon: IconNode;
  run: () => void;
}

/**
 * The entries of the "Aggiungi" menu (lib/app/app_shell.dart): income or
 * expense always; transfers with two or more wallets; meal-voucher loads
 * and expenses when a voucher wallet exists. With only income/expense
 * available the button opens the form directly.
 */
@Injectable({ providedIn: 'root' })
export class AddActions {
  private readonly router = inject(Router);
  private readonly wallets = inject(WalletsStore);
  private readonly dialogs = inject(WalletDialogs);

  readonly actions = computed<AddAction[]>(() => [
    {
      id: 'standard',
      labelKey: 'webAddIncomeExpense',
      icon: ArrowUpDown,
      run: () => void this.router.navigateByUrl('/app/transactions/new'),
    },
    ...(this.wallets.hasMultipleWallets()
      ? [
          {
            id: 'transfer',
            labelKey: 'webAddTransfer',
            icon: ArrowLeftRight,
            run: () => void this.dialogs.transfer(),
          },
        ]
      : []),
    ...(this.wallets.hasVoucherWallet()
      ? [
          {
            id: 'voucher-credit',
            labelKey: 'webAddVoucherCredit',
            icon: TicketPlus,
            run: () => void this.dialogs.voucherCredit(true),
          },
        ]
      : []),
  ]);

  /** True when the button should open the form without a menu. */
  readonly direct = computed(() => this.actions().length === 1);

  runDefault(): void {
    this.actions()[0].run();
  }
}
