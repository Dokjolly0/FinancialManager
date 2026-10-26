import { reportFilterFromParams, reportFilterToParams, reportParams } from './report-filter';

describe('report filter', () => {
  it('defaults to the last 30 days and round-trips through the URL', () => {
    const filter = reportFilterFromParams({});
    expect(filter).toMatchObject({
      preset: 'last_30_days',
      includeAdjustments: false,
    });
    const custom = reportFilterFromParams({
      preset: 'custom',
      from: '2026-10-01',
      to: '2026-10-31',
      adj: '1',
    });
    expect(reportFilterFromParams(reportFilterToParams(custom))).toEqual(custom);
  });

  it('waits for a complete custom range and sends local noon', () => {
    expect(
      reportParams(reportFilterFromParams({ preset: 'custom', from: '2026-10-01' })),
    ).toBeNull();
    expect(
      reportParams(
        reportFilterFromParams({ preset: 'custom', from: '2026-10-31', to: '2026-10-01' }),
      ),
    ).toBeNull();
    const params = reportParams(
      reportFilterFromParams({ preset: 'custom', from: '2026-10-01', to: '2026-10-31' }),
    )!;
    expect(new Date(params.from!).getHours()).toBe(12);
    expect(new Date(params.to!).getDate()).toBe(31);
  });

  it('passes presets through with wallet and adjustments', () => {
    expect(
      reportParams(reportFilterFromParams({ preset: 'current_year', wallet: 'w1', adj: '1' })),
    ).toEqual({
      preset: 'current_year',
      wallet_id: 'w1',
      include_adjustments: true,
    });
  });
});
