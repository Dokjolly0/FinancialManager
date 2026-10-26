import { Transaction } from '../transactions/transaction.model';
import {
  EMPTY_FILTER,
  activeCount,
  aiPrefill,
  filterFromParams,
  filterToParams,
  filterToQuery,
  groupByDay,
} from './history-filter';

describe('history filter', () => {
  it('round-trips through the URL and drops bad values', () => {
    const filter = filterFromParams({
      type: 'credit',
      wallet: 'w1',
      q: 'pizza',
      min: '500',
      max: 'abc',
      from: '2026-10-01',
      to: 'nope',
    });
    expect(filter).toEqual({
      ...EMPTY_FILTER,
      type: 'credit',
      walletId: 'w1',
      title: 'pizza',
      amountMin: 500,
      from: '2026-10-01',
    });
    expect(filterFromParams(filterToParams(filter))).toEqual(filter);
    expect(filterFromParams({ type: 'weird' }).type).toBe('all');
  });

  it('keeps the "no category" filter through the URL, the query and the AI prefill', () => {
    const filter = filterFromParams({ category: 'none' });
    expect(filter.categoryId).toBe('none');
    expect(filterFromParams(filterToParams(filter))).toEqual(filter);
    expect(filterToQuery(filter).category_id).toBe('none');
    expect(activeCount(filter)).toBe(1);
    const prefill = aiPrefill(filter);
    expect('params' in prefill && prefill.params['category']).toBe('none');
  });

  it('counts active filters like the app', () => {
    expect(activeCount(EMPTY_FILTER)).toBe(0);
    expect(activeCount({ ...EMPTY_FILTER, type: 'debit', title: ' x ', from: '2026-01-01' })).toBe(
      3,
    );
  });

  it('maps the type filter to direction and kind', () => {
    expect(filterToQuery({ ...EMPTY_FILTER, type: 'debit' })).toMatchObject({
      direction: 'DEBIT',
      kind: 'STANDARD',
    });
    expect(filterToQuery({ ...EMPTY_FILTER, type: 'transfers' })).toMatchObject({
      direction: null,
      kind: 'TRANSFER',
    });
    expect(filterToQuery(EMPTY_FILTER)).toMatchObject({ direction: null, kind: null });
  });

  it('sends the end day as the exclusive start of the next day', () => {
    const query = filterToQuery({ ...EMPTY_FILTER, from: '2026-10-01', to: '2026-10-31' });
    expect(new Date(query.occurred_from!).getDate()).toBe(1);
    const to = new Date(query.occurred_to!);
    expect([to.getMonth(), to.getDate(), to.getHours()]).toEqual([10, 1, 0]);
  });

  it('refuses AI prefill for adjustments and transfers', () => {
    expect(aiPrefill({ ...EMPTY_FILTER, type: 'adjustments' })).toEqual({ problem: 'adjustments' });
    expect(aiPrefill({ ...EMPTY_FILTER, type: 'credit', title: 'x' })).toMatchObject({
      params: { direction: 'CREDIT', title: 'x', fromHistory: 1 },
    });
  });
});

describe('groupByDay', () => {
  const t = (id: string, occurred: Date, direction: 'CREDIT' | 'DEBIT', amount: number) =>
    ({ id, occurred_at: occurred.toISOString(), direction, amount_minor: amount }) as Transaction;

  it('groups by local day, newest first, with the day net', () => {
    const groups = groupByDay([
      t('a', new Date(2026, 9, 23, 18), 'DEBIT', 1000),
      t('b', new Date(2026, 9, 23, 9), 'CREDIT', 5000),
      t('c', new Date(2026, 9, 21, 12), 'DEBIT', 250),
    ]);
    expect(groups.map((g) => [g.day, g.transactions.length, g.netMinor])).toEqual([
      ['2026-10-23', 2, 4000],
      ['2026-10-21', 1, -250],
    ]);
  });
});
