import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import type { IconNode } from 'lucide';
import { ArrowUpDown } from 'lucide';

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

  /** Extra entries registered by features that own their dialogs. */
  private readonly extra = signal<((wallets: WalletsStore) => AddAction[])[]>([]);

  readonly actions = computed<AddAction[]>(() => {
    const standard: AddAction = {
      id: 'standard',
      labelKey: 'webAddIncomeExpense',
      icon: ArrowUpDown,
      run: () => void this.router.navigateByUrl('/app/transactions/new'),
    };
    return [standard, ...this.extra().flatMap((provide) => provide(this.wallets))];
  });

  /** True when the button should open the form without a menu. */
  readonly direct = computed(() => this.actions().length === 1);

  register(provide: (wallets: WalletsStore) => AddAction[]): void {
    this.extra.update((list) => [...list, provide]);
  }

  runDefault(): void {
    this.actions()[0].run();
  }
}
