import { Wallet } from '../wallets/wallet.model';

export type Direction = 'CREDIT' | 'DEBIT';

/**
 * Technical nature of an operation (plan.md section 4.2). Only STANDARD is
 * created, edited and deleted through the ordinary form; OPENING_BALANCE and
 * TRANSFER can have amount and date corrected through their own forms but
 * are never deleted; BALANCE_ADJUSTMENT is read-only once made.
 */
export type TransactionKind = 'STANDARD' | 'OPENING_BALANCE' | 'BALANCE_ADJUSTMENT' | 'TRANSFER';

/** One ledger row as the API returns it. Amounts are always positive. */
export interface Transaction {
  id: string;
  wallet_id: string;
  direction: Direction;
  kind: TransactionKind;
  amount_minor: number;
  currency: string;
  title: string;
  description?: string | null;
  category_id?: string | null;
  template_id?: string | null;
  media_id?: string | null;
  transfer_pair_id?: string | null;
  /**
   * Pairs a meal-voucher expense's two DEBIT legs (voucher wallet and the
   * other wallet covering the difference). Null when the vouchers covered
   * it all, so alone it can't identify every voucher expense.
   */
  linked_transaction_id?: string | null;
  /** The automatic "expired vouchers" write-off: never user-editable. */
  system_generated?: boolean;
  /** Shared by the installments the user linked as one expense. */
  payment_group_id?: string | null;
  occurred_at: string;
  created_at: string;
  updated_at: string;
  version: number;
}

export interface TransactionPage {
  transactions: Transaction[] | null;
  next_cursor?: string | null;
  has_more?: boolean;
}

/** What create/update return: the row and the wallet's authoritative new balance. */
export interface TransactionWithWallet {
  transaction?: Transaction | null;
  wallet: Wallet;
}

export interface PaymentGroupSummary {
  payment_group_id: string;
  member_count: number;
  net_amount_minor: number;
  currency: string;
  representative_transaction_id: string;
  representative_title: string;
}

/** Editable through the plain form (the app's LedgerTransaction.isEditable). */
export const isEditable = (t: Transaction) =>
  t.kind === 'STANDARD' && !t.linked_transaction_id && !t.system_generated;

export const isCredit = (t: Pick<Transaction, 'direction'>) => t.direction === 'CREDIT';

/** ARB key of the label shown instead of the category for special kinds. */
export function kindLabelKey(kind: TransactionKind): string | null {
  switch (kind) {
    case 'OPENING_BALANCE':
      return 'openingBalanceKindLabel';
    case 'BALANCE_ADJUSTMENT':
      return 'balanceAdjustmentKindLabel';
    case 'TRANSFER':
      return 'transferKindLabel';
    default:
      return null;
  }
}
