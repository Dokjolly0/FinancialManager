import { computed, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';

import { WalletDialogs } from '../features/wallets/wallet-dialogs';
import { Wallet } from '../features/wallets/wallet.model';
import { WalletsStore } from '../features/wallets/wallets.store';
import { AddActions } from './add-actions';

function wallet(type: Wallet['type'], id = type): Wallet {
  return {
    id,
    name: id,
    type,
    icon: 'wallet',
    color: '#176B5B',
    current_balance_minor: 0,
    currency: 'EUR',
    version: 1,
    updated_at: '2026-10-01T00:00:00Z',
  };
}

describe('AddActions', () => {
  const wallets = signal<Wallet[]>([]);

  beforeEach(() => {
    const store = {
      hasMultipleWallets: computed(() => wallets().length >= 2),
      hasVoucherWallet: computed(() => wallets().some((w) => w.type === 'MEAL_VOUCHER')),
    };
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: WalletsStore, useValue: store },
        { provide: WalletDialogs, useValue: {} },
      ],
    });
  });

  const ids = () =>
    TestBed.inject(AddActions)
      .actions()
      .map((action) => action.id);

  it('opens the form directly with one plain wallet', () => {
    wallets.set([wallet('BANK')]);
    expect(ids()).toEqual(['standard']);
    expect(TestBed.inject(AddActions).direct()).toBe(true);
  });

  it('offers transfers from two wallets', () => {
    wallets.set([wallet('BANK'), wallet('CASH')]);
    expect(ids()).toEqual(['standard', 'transfer']);
  });

  it('offers voucher loads with a meal-voucher wallet', () => {
    wallets.set([wallet('MEAL_VOUCHER')]);
    expect(ids()).toEqual(['standard', 'voucher-credit', 'voucher-expense']);
    wallets.set([wallet('BANK'), wallet('MEAL_VOUCHER')]);
    expect(ids()).toEqual(['standard', 'transfer', 'voucher-credit', 'voucher-expense']);
  });
});
