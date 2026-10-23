import { Params } from '@angular/router';

import { fromDateInput } from '../../core/formatting/dates';
import { ReportParams, ReportPreset } from './reports.api';

export const PRESETS: ReportPreset[] = [
  'last_30_days',
  'current_month',
  'last_12_months',
  'current_year',
  'all_time',
  'custom',
];

export const PRESET_KEYS: Record<ReportPreset, string> = {
  last_30_days: 'webPresetLast30Days',
  current_month: 'webPresetCurrentMonth',
  last_12_months: 'webPresetLast12Months',
  current_year: 'webPresetCurrentYear',
  all_time: 'webPresetAllTime',
  custom: 'webPresetCustom',
};

/** What the reports page shows, kept in its URL like the History filters. */
export interface ReportFilter {
  preset: ReportPreset;
  /** Custom range, local days "YYYY-MM-DD", both inclusive. */
  from: string | null;
  to: string | null;
  walletId: string | null;
  includeAdjustments: boolean;
  groupBy: 'category' | 'title';
}

export function reportFilterFromParams(params: Params): ReportFilter {
  const preset = PRESETS.includes(params['preset'])
    ? (params['preset'] as ReportPreset)
    : 'last_30_days';
  const day = (value: unknown) =>
    typeof value === 'string' && fromDateInput(value) ? value : null;
  return {
    preset,
    from: day(params['from']),
    to: day(params['to']),
    walletId: typeof params['wallet'] === 'string' ? params['wallet'] : null,
    includeAdjustments: params['adj'] === '1' || params['adj'] === 1,
    groupBy: params['group'] === 'title' ? 'title' : 'category',
  };
}

export function reportFilterToParams(filter: ReportFilter): Params {
  const custom = filter.preset === 'custom';
  return {
    preset: filter.preset === 'last_30_days' ? null : filter.preset,
    from: custom ? filter.from : null,
    to: custom ? filter.to : null,
    wallet: filter.walletId,
    adj: filter.includeAdjustments ? 1 : null,
    group: filter.groupBy === 'title' ? 'title' : null,
  };
}

/**
 * API params, or null while a custom range is incomplete. Custom days go as
 * local noon: the backend takes each one's calendar day in the profile's
 * time zone, and noon keeps the same day across any nearby zone.
 */
export function reportParams(filter: ReportFilter): ReportParams | null {
  const noon = (value: string | null) => {
    const date = value ? fromDateInput(value) : null;
    return date
      ? new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12).toISOString()
      : null;
  };
  if (filter.preset === 'custom') {
    const from = noon(filter.from);
    const to = noon(filter.to);
    if (!from || !to || filter.to! < filter.from!) return null;
    return {
      preset: 'custom',
      from,
      to,
      wallet_id: filter.walletId,
      include_adjustments: filter.includeAdjustments,
    };
  }
  return {
    preset: filter.preset,
    wallet_id: filter.walletId,
    include_adjustments: filter.includeAdjustments,
  };
}
