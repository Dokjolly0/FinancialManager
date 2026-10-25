import { Params } from '@angular/router';

import { fromDateInput, toDateInput } from '../../core/formatting/dates';
import { Direction, Transaction } from '../transactions/transaction.model';
import { TransactionQuery } from '../transactions/transactions.api';

/** The History type filter (plan.md section 7.9). */
export type TypeFilter = 'all' | 'debit' | 'credit' | 'adjustments' | 'transfers';
export const TYPE_FILTERS: TypeFilter[] = ['all', 'debit', 'credit', 'adjustments', 'transfers'];

/**
 * History filters, kept in the page URL so a filtered view can be reloaded,
 * shared and navigated back to. Dates are local calendar days, both
 * inclusive.
 */
export interface HistoryFilter {
  type: TypeFilter;
  walletId: string | null;
  categoryId: string | null;
  /** Matches title or description. */
  title: string;
  amountMin: number | null;
  amountMax: number | null;
  /** "YYYY-MM-DD" */
  from: string | null;
  to: string | null;
}

export const EMPTY_FILTER: HistoryFilter = {
  type: 'all',
  walletId: null,
  categoryId: null,
  title: '',
  amountMin: null,
  amountMax: null,
  from: null,
  to: null,
};

const intOrNull = (value: unknown): number | null => {
  const n =
    typeof value === 'number'
      ? value
      : typeof value === 'string' && value !== ''
        ? Number(value)
        : NaN;
  return Number.isSafeInteger(n) && n >= 0 ? n : null;
};
const dayOrNull = (value: unknown): string | null =>
  typeof value === 'string' && fromDateInput(value) ? value : null;

export function filterFromParams(params: Params): HistoryFilter {
  const type = TYPE_FILTERS.includes(params['type']) ? (params['type'] as TypeFilter) : 'all';
  return {
    type,
    walletId: typeof params['wallet'] === 'string' ? params['wallet'] : null,
    categoryId: typeof params['category'] === 'string' ? params['category'] : null,
    title: typeof params['q'] === 'string' ? params['q'] : '',
    amountMin: intOrNull(params['min']),
    amountMax: intOrNull(params['max']),
    from: dayOrNull(params['from']),
    to: dayOrNull(params['to']),
  };
}

/** Query params of a filter; unset values are null so navigation removes them. */
export function filterToParams(filter: HistoryFilter): Params {
  return {
    type: filter.type === 'all' ? null : filter.type,
    wallet: filter.walletId,
    category: filter.categoryId,
    q: filter.title.trim() || null,
    min: filter.amountMin,
    max: filter.amountMax,
    from: filter.from,
    to: filter.to,
  };
}

/** Badge count of the filter button; the search box counts as one (the app's activeCount). */
export function activeCount(filter: HistoryFilter): number {
  return [
    filter.type !== 'all',
    !!filter.walletId,
    !!filter.title.trim(),
    !!filter.categoryId,
    filter.amountMin !== null,
    filter.amountMax !== null,
    !!filter.from,
    !!filter.to,
  ].filter(Boolean).length;
}

/**
 * The API query: standard operations are filtered by direction, while
 * adjustments and transfers are each a kind in either direction; "all"
 * leaves both unset. The "to" day is inclusive here and exclusive (start of
 * the next day) for the API.
 */
export function filterToQuery(filter: HistoryFilter): Omit<TransactionQuery, 'limit' | 'cursor'> {
  const [direction, kind]: [Direction | null, string | null] = (() => {
    switch (filter.type) {
      case 'debit':
        return ['DEBIT', 'STANDARD'];
      case 'credit':
        return ['CREDIT', 'STANDARD'];
      case 'adjustments':
        return [null, 'BALANCE_ADJUSTMENT'];
      case 'transfers':
        return [null, 'TRANSFER'];
      default:
        return [null, null];
    }
  })();
  const from = filter.from ? fromDateInput(filter.from) : null;
  const toDay = filter.to ? fromDateInput(filter.to) : null;
  const to = toDay ? new Date(toDay.getFullYear(), toDay.getMonth(), toDay.getDate() + 1) : null;
  return {
    direction,
    kind,
    wallet_id: filter.walletId,
    category_id: filter.categoryId,
    title: filter.title.trim() || null,
    amount_min_minor: filter.amountMin,
    amount_max_minor: filter.amountMax,
    occurred_from: from?.toISOString() ?? null,
    occurred_to: to?.toISOString() ?? null,
  };
}

/**
 * "Analyze with AI" on what History shows (plan.md section 32.6), as the
 * query params of /app/ai/new. The analysis only looks at income and
 * expenses: adjustment or transfer filters can't be honoured.
 */
export function aiPrefill(
  filter: HistoryFilter,
): { params: Params } | { problem: 'adjustments' | 'transfers' } {
  if (filter.type === 'adjustments') return { problem: 'adjustments' };
  if (filter.type === 'transfers') return { problem: 'transfers' };
  return {
    params: {
      fromHistory: 1,
      wallet: filter.walletId,
      direction: filter.type === 'debit' ? 'DEBIT' : filter.type === 'credit' ? 'CREDIT' : null,
      category: filter.categoryId,
      title: filter.title.trim() || null,
      min: filter.amountMin,
      max: filter.amountMax,
      from: filter.from,
      to: filter.to,
    },
  };
}

export interface DayGroup {
  /** "YYYY-MM-DD", local. */
  day: string;
  transactions: Transaction[];
  /** Credits minus debits of the day. */
  netMinor: number;
}

/** Groups operations (newest first, as the API returns them) by local day. */
export function groupByDay(transactions: Transaction[]): DayGroup[] {
  const groups: DayGroup[] = [];
  for (const t of transactions) {
    const day = toDateInput(new Date(t.occurred_at));
    let group = groups.find((g) => g.day === day);
    if (!group) {
      group = { day, transactions: [], netMinor: 0 };
      groups.push(group);
    }
    group.transactions.push(t);
    group.netMinor += t.direction === 'CREDIT' ? t.amount_minor : -t.amount_minor;
  }
  return groups.sort((a, b) => b.day.localeCompare(a.day));
}
