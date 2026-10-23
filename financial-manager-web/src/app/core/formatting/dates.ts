/**
 * Date presets used across the dashboard, in the browser's time zone (the
 * app shows dates with toLocal()). Timestamps travel in UTC (plan.md
 * section 4.5).
 */
export type DateStyle =
  | 'date' // 3 mar 2026
  | 'dateLong' // 3 marzo 2026
  | 'dateTime' // 3 mar 2026, 14:05
  | 'dateTimeLong' // 3 marzo 2026, 14:05
  | 'dayHeader' // martedì 3 marzo
  | 'dayMonth' // 3 mar
  | 'monthYear' // marzo 2026
  | 'monthShort' // mar
  | 'time'; // 14:05

const OPTIONS: Record<DateStyle, Intl.DateTimeFormatOptions> = {
  date: { day: 'numeric', month: 'short', year: 'numeric' },
  dateLong: { day: 'numeric', month: 'long', year: 'numeric' },
  dateTime: { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' },
  dateTimeLong: {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  },
  dayHeader: { weekday: 'long', day: 'numeric', month: 'long' },
  dayMonth: { day: 'numeric', month: 'short' },
  monthYear: { month: 'long', year: 'numeric' },
  monthShort: { month: 'short' },
  time: { hour: '2-digit', minute: '2-digit' },
};

const formatters = new Map<string, Intl.DateTimeFormat>();

export function formatDate(value: string | Date, style: DateStyle, locale: string): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return '';
  const key = `${locale}|${style}`;
  let formatter = formatters.get(key);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, OPTIONS[style]);
    formatters.set(key, formatter);
  }
  return formatter.format(date);
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Local calendar date as "YYYY-MM-DD" (<input type="date"> values, day keys). */
export function toDateInput(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Local date and time as "YYYY-MM-DDTHH:mm" (<input type="datetime-local">). */
export function toDateTimeInput(date: Date): string {
  return `${toDateInput(date)}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** Parses "YYYY-MM-DD" as local midnight. */
export function fromDateInput(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

/** Parses "YYYY-MM-DDTHH:mm" as local time. */
export function fromDateTimeInput(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value);
  if (!match) return null;
  return new Date(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
    Number(match[4]),
    Number(match[5]),
  );
}

/** The browser's IANA time zone, sent where the API needs one (reports, register). */
export function browserTimeZone(): string {
  return Intl.DateTimeFormat().resolvedOptions().timeZone || 'Europe/Rome';
}
