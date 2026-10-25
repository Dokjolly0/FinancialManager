import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, idempotencyHeaders } from '../../core/api/api';
import { Ledger } from '../../core/state/ledger';
import { VoucherLot, Wallet, WalletDenomination, WalletType } from './wallet.model';

export interface WalletFields {
  name: string;
  type: WalletType;
  icon: string;
  color: string;
  purpose: string | null;
  voucher_expiry_cutoff_month: number | null;
  voucher_expiry_month: number | null;
  voucher_expiry_day: number | null;
}

export interface CreateWalletBody extends WalletFields {
  opening_balance_minor?: number | null;
  voucher_unit_value_minor?: number | null;
  initial_voucher_quantity?: number | null;
  voucher_loaded_at?: string | null;
}

/** /v1/wallets* (plan.md multi-wallet extension). */
@Injectable({ providedIn: 'root' })
export class WalletsApi {
  private readonly http = inject(HttpClient);
  private readonly ledger = inject(Ledger);

  get(id: string): Promise<Wallet> {
    return firstValueFrom(this.http.get<Wallet>(api(`/wallets/${id}`)));
  }

  async create(body: CreateWalletBody): Promise<Wallet> {
    const response = await firstValueFrom(
      this.http.post<{ wallet?: Wallet } & Partial<Wallet>>(api('/wallets'), body, {
        headers: idempotencyHeaders(),
      }),
    );
    this.ledger.changed();
    return (response.wallet ?? response) as Wallet;
  }

  async update(id: string, body: WalletFields & { version: number }): Promise<Wallet> {
    const wallet = await firstValueFrom(this.http.patch<Wallet>(api(`/wallets/${id}`), body));
    this.ledger.changed();
    return wallet;
  }

  async archive(id: string, version: number): Promise<Wallet> {
    const wallet = await firstValueFrom(
      this.http.post<Wallet>(api(`/wallets/${id}/archive`), { version }),
    );
    this.ledger.changed();
    return wallet;
  }

  async denominations(walletId: string): Promise<WalletDenomination[]> {
    const response = await firstValueFrom(
      this.http.get<{ denominations: WalletDenomination[] | null }>(
        api(`/wallets/${walletId}/denominations`),
      ),
    );
    return response.denominations ?? [];
  }

  async replaceDenominations(
    walletId: string,
    denominations: WalletDenomination[],
  ): Promise<WalletDenomination[]> {
    const response = await firstValueFrom(
      this.http.put<{ denominations: WalletDenomination[] | null }>(
        api(`/wallets/${walletId}/denominations`),
        { denominations },
      ),
    );
    return response.denominations ?? [];
  }

  async voucherLots(walletId: string): Promise<VoucherLot[]> {
    const response = await firstValueFrom(
      this.http.get<{ voucher_lots: VoucherLot[] | null }>(
        api(`/wallets/${walletId}/voucher-lots`),
      ),
    );
    return response.voucher_lots ?? [];
  }
}
