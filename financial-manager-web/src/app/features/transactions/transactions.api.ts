import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, firstValueFrom } from 'rxjs';

import { api, idempotencyHeaders, query } from '../../core/api/api';
import { Ledger } from '../../core/state/ledger';
import { Wallet } from '../wallets/wallet.model';
import {
  Direction,
  PaymentGroupSummary,
  Transaction,
  TransactionPage,
  TransactionWithWallet,
} from './transaction.model';

export interface TransactionQuery {
  cursor?: string | null;
  limit: number;
  wallet_id?: string | null;
  direction?: Direction | null;
  kind?: string | null;
  category_id?: string | null;
  title?: string | null;
  amount_min_minor?: number | null;
  amount_max_minor?: number | null;
  /** ISO timestamps (UTC). */
  occurred_from?: string | null;
  occurred_to?: string | null;
  payment_group_id?: string | null;
}

export interface TransactionBody {
  wallet_id: string;
  direction: Direction;
  amount_minor: number;
  title: string;
  description: string | null;
  category_id: string | null;
  template_id: string | null;
  media_id: string | null;
  occurred_at: string;
}

export interface VoucherExpenseBody {
  voucher_quantity: number;
  total_expense_minor: number;
  other_wallet_id: string | null;
  title: string;
  description: string | null;
  category_id?: string | null;
  template_id?: string | null;
  media_id: string | null;
  occurred_at: string;
}

export interface VoucherExpenseResult {
  voucher_transaction: Transaction;
  voucher_wallet: Wallet;
  other_transaction?: Transaction | null;
  other_wallet?: Wallet | null;
}

/**
 * /v1/transactions, transfers, adjustments and meal vouchers (plan.md
 * sections 14.4, 14.5). Every successful change bumps the Ledger revision so
 * balances and lists everywhere reload.
 */
@Injectable({ providedIn: 'root' })
export class TransactionsApi {
  private readonly http = inject(HttpClient);
  private readonly ledger = inject(Ledger);

  list(params: TransactionQuery): Promise<TransactionPage> {
    return firstValueFrom(
      this.http.get<TransactionPage>(api('/transactions'), {
        params: query({ ...params }),
      }),
    );
  }

  get(id: string): Promise<Transaction> {
    return firstValueFrom(this.http.get<Transaction>(api(`/transactions/${id}`)));
  }

  /** The wallet's opening-balance row, if it has one. */
  async openingBalance(walletId: string): Promise<Transaction | null> {
    const page = await this.list({ limit: 1, wallet_id: walletId, kind: 'OPENING_BALANCE' });
    return page.transactions?.[0] ?? null;
  }

  create(body: TransactionBody & { currency: string; link_to_transaction_id?: string | null }) {
    return this.changed(
      this.http.post<TransactionWithWallet>(api('/transactions'), body, {
        headers: idempotencyHeaders(),
      }),
    );
  }

  update(id: string, body: TransactionBody & { version: number }) {
    return this.changed(this.http.patch<TransactionWithWallet>(api(`/transactions/${id}`), body));
  }

  delete(id: string) {
    return this.changed(this.http.delete<{ wallet: Wallet }>(api(`/transactions/${id}`)));
  }

  updateOpeningBalance(
    id: string,
    body: { amount_minor: number; occurred_at: string; version: number },
  ) {
    return this.changed(
      this.http.patch<TransactionWithWallet>(api(`/transactions/${id}/opening-balance`), body),
    );
  }

  updateTransfer(id: string, body: { amount_minor: number; occurred_at: string; version: number }) {
    return this.changed(this.http.patch<unknown>(api(`/transactions/${id}/transfer`), body));
  }

  createTransfer(body: {
    source_wallet_id: string;
    destination_wallet_id: string;
    amount_minor: number;
    note: string | null;
    occurred_at: string;
  }) {
    return this.changed(
      this.http.post<unknown>(api('/transfers'), body, { headers: idempotencyHeaders() }),
    );
  }

  /** Sets the wallet's balance to a target; the server computes the difference. */
  createBalanceAdjustment(
    walletId: string,
    body: { target_balance_minor: number; reason: string | null },
  ) {
    return this.changed(
      this.http.post<TransactionWithWallet>(api(`/wallets/${walletId}/balance-adjustments`), body, {
        headers: idempotencyHeaders(),
      }),
    );
  }

  /** Adds (positive quantity) or removes (negative) meal vouchers outside a purchase. */
  createVoucherCredit(
    walletId: string,
    body: { quantity: number; reason: string | null; occurred_at: string },
  ) {
    return this.changed(
      this.http.post<TransactionWithWallet>(api(`/wallets/${walletId}/voucher-credits`), body, {
        headers: idempotencyHeaders(),
      }),
    );
  }

  updateVoucherCredit(
    walletId: string,
    transactionId: string,
    body: { quantity: number; reason: string | null; occurred_at: string; version: number },
  ) {
    return this.changed(
      this.http.patch<TransactionWithWallet>(
        api(`/wallets/${walletId}/voucher-credits/${transactionId}`),
        body,
      ),
    );
  }

  createVoucherExpense(body: VoucherExpenseBody & { voucher_wallet_id: string }) {
    return this.changed(
      this.http.post<VoucherExpenseResult>(api('/voucher-expenses'), body, {
        headers: idempotencyHeaders(),
      }),
    );
  }

  updateVoucherExpense(id: string, body: VoucherExpenseBody & { version: number }) {
    return this.changed(
      this.http.patch<VoucherExpenseResult>(api(`/voucher-expenses/${id}`), body),
    );
  }

  paymentGroups(): Promise<PaymentGroupSummary[]> {
    return firstValueFrom(
      this.http.get<{ payment_groups: PaymentGroupSummary[] | null }>(
        api('/transactions/payment-groups'),
      ),
    ).then((response) => response.payment_groups ?? []);
  }

  unlinkPaymentGroup(id: string) {
    return this.changed(this.http.delete<unknown>(api(`/transactions/${id}/payment-group-link`)));
  }

  private async changed<T>(request: Observable<T>): Promise<T> {
    const result = await firstValueFrom(request);
    this.ledger.changed();
    return result;
  }
}
