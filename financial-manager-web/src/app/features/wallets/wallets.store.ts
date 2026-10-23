import { httpResource } from '@angular/common/http';
import { Injectable, computed, inject } from '@angular/core';

import { api } from '../../core/api/api';
import { Ledger } from '../../core/state/ledger';
import { Wallet, isMealVoucher } from './wallet.model';

/**
 * The user's active wallets, shared by the shell ("Aggiungi" menu), Home,
 * the pickers and the wallet screens (the app's walletsListProvider).
 * Reloads after every ledger change, since balances move.
 */
@Injectable({ providedIn: 'root' })
export class WalletsStore {
  private readonly ledger = inject(Ledger);

  private readonly resource = httpResource<{ wallets: Wallet[] | null }>(() => {
    this.ledger.revision();
    return api('/wallets');
  });

  readonly wallets = computed<Wallet[]>(() => this.resource.value()?.wallets ?? []);
  readonly loading = computed(() => this.resource.isLoading() && !this.resource.hasValue());
  readonly error = computed(() => this.resource.error());
  readonly loaded = computed(() => this.resource.hasValue());

  readonly voucherWallets = computed(() => this.wallets().filter(isMealVoucher));
  readonly hasVoucherWallet = computed(() => this.voucherWallets().length > 0);
  readonly hasMultipleWallets = computed(() => this.wallets().length >= 2);
  /** Sum of the balances (every wallet is in the profile currency, EUR). */
  readonly totalMinor = computed(() =>
    this.wallets().reduce((sum, wallet) => sum + wallet.current_balance_minor, 0),
  );
  readonly currency = computed(() => this.wallets()[0]?.currency ?? 'EUR');

  byId(id: string | null | undefined): Wallet | undefined {
    return this.wallets().find((wallet) => wallet.id === id);
  }

  reload(): void {
    this.resource.reload();
  }
}
