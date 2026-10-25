import { matchQuick, periodFields, quickRange } from './ai-period';

describe('AI quick periods', () => {
  const today = new Date(2026, 9, 23); // 23 October 2026

  it('computes the app ranges', () => {
    expect(quickRange('last30Days', today)).toEqual({ from: '2026-09-24', to: '2026-10-23' });
    expect(quickRange('currentMonth', today)).toEqual({ from: '2026-10-01', to: '2026-10-23' });
    expect(quickRange('lastMonth', today)).toEqual({ from: '2026-09-01', to: '2026-09-30' });
    expect(quickRange('lastQuarter', today)).toEqual({ from: '2026-07-01', to: '2026-09-30' });
    expect(quickRange('currentYear', today)).toEqual({ from: '2026-01-01', to: '2026-10-23' });
    expect(quickRange('last12Months', today)).toEqual({ from: '2025-10-24', to: '2026-10-23' });
    expect(quickRange('allTime', today)).toEqual({ from: null, to: null });
  });

  it('handles the quarter across the year boundary', () => {
    expect(quickRange('lastQuarter', new Date(2026, 1, 10))).toEqual({
      from: '2025-10-01',
      to: '2025-12-31',
    });
  });

  it('recognizes a shortcut and builds the request period', () => {
    expect(matchQuick({ from: '2026-09-01', to: '2026-09-30' }, today)).toBe('lastMonth');
    expect(matchQuick({ from: '2026-09-02', to: '2026-09-30' }, today)).toBeNull();
    expect(periodFields({ from: null, to: null })).toEqual({ preset: 'all_time' });
    expect(periodFields({ from: '2026-01-01', to: null })).toEqual({
      preset: 'custom',
      from: '2026-01-01',
    });
  });
});
