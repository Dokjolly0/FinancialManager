import { Injectable, signal } from '@angular/core';

/**
 * Bumped by every successful ledger change (create, edit or delete an
 * operation, transfer, adjustment, vouchers): screens showing balances or
 * operations read `revision` in their resources and reload, without the
 * changing feature knowing who shows what (the app's ledgerRevisionProvider).
 */
@Injectable({ providedIn: 'root' })
export class Ledger {
  private readonly counter = signal(0);
  readonly revision = this.counter.asReadonly();

  changed(): void {
    this.counter.update((value) => value + 1);
  }
}
