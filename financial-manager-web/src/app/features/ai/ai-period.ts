import { toDateInput } from '../../core/formatting/dates';

/** Shortcuts of the setup page (the app's AiQuickPeriod); each fills From/To. */
export type QuickPeriod =
  | 'last30Days'
  | 'currentMonth'
  | 'lastMonth'
  | 'lastQuarter'
  | 'currentYear'
  | 'last12Months'
  | 'allTime';

export const QUICK_PERIODS: { id: QuickPeriod; key: string }[] = [
  { id: 'last30Days', key: 'aiPeriodLast30Days' },
  { id: 'currentMonth', key: 'aiPeriodCurrentMonth' },
  { id: 'lastMonth', key: 'aiPeriodLastMonth' },
  { id: 'lastQuarter', key: 'aiPeriodLastQuarter' },
  { id: 'currentYear', key: 'aiPeriodCurrentYear' },
  { id: 'last12Months', key: 'aiPeriodLast12Months' },
  { id: 'allTime', key: 'aiPeriodAllTime' },
];

/** Inclusive local days "YYYY-MM-DD"; null is open. */
export interface DayRange {
  from: string | null;
  to: string | null;
}

const day = (y: number, m: number, d: number) => toDateInput(new Date(y, m, d));

/** The dates a shortcut stands for, relative to today (ai_period.dart's aiQuickRange). */
export function quickRange(period: QuickPeriod, today = new Date()): DayRange {
  const y = today.getFullYear();
  const m = today.getMonth();
  const d = today.getDate();
  const t = day(y, m, d);
  switch (period) {
    case 'last30Days':
      return { from: day(y, m, d - 29), to: t };
    case 'currentMonth':
      return { from: day(y, m, 1), to: t };
    case 'lastMonth':
      return { from: day(y, m - 1, 1), to: day(y, m, 0) };
    case 'lastQuarter': {
      const quarterStart = Math.floor(m / 3) * 3;
      return { from: day(y, quarterStart - 3, 1), to: day(y, quarterStart, 0) };
    }
    case 'currentYear':
      return { from: day(y, 0, 1), to: t };
    case 'last12Months':
      return { from: day(y - 1, m, d + 1), to: t };
    case 'allTime':
      return { from: null, to: null };
  }
}

/** The shortcut whose dates equal the range, to highlight it. */
export function matchQuick(range: DayRange, today = new Date()): QuickPeriod | null {
  return (
    QUICK_PERIODS.find(({ id }) => {
      const q = quickRange(id, today);
      return q.from === range.from && q.to === range.to;
    })?.id ?? null
  );
}

/** Request period: no bounds is the whole history, otherwise custom with the set bounds. */
export function periodFields(range: DayRange): {
  preset: 'all_time' | 'custom';
  from?: string;
  to?: string;
} {
  if (!range.from && !range.to) return { preset: 'all_time' };
  return {
    preset: 'custom',
    ...(range.from ? { from: range.from } : {}),
    ...(range.to ? { to: range.to } : {}),
  };
}
