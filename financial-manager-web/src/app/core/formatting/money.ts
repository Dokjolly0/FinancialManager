/**
 * Amounts are integer minor units (cents) plus an ISO-4217 currency, never
 * floating point (plan.md sections 4.3, 9.7; the app's Money). The wire
 * format is {"amount_minor": 1234, "currency": "EUR"}.
 */

/**
 * Parses an amount typed by the user into minor units: "500", "500,5",
 * "500.50" (either decimal separator, at most two decimals). Null when the
 * input isn't a valid non-negative amount, so the form shows an error
 * instead of guessing. Digits are read as text: no float rounding.
 */
export function parseMinorUnits(input: string): number | null {
  const normalized = input.trim().replace(/\s/g, '').replace(',', '.');
  const match = /^(\d+)(?:\.(\d{0,2}))?$/.exec(normalized);
  if (!match) return null;
  const units = Number.parseInt(match[1], 10);
  const cents = Number.parseInt((match[2] ?? '').padEnd(2, '0'), 10);
  const value = units * 100 + cents;
  return Number.isSafeInteger(value) ? value : null;
}

/** Minor units as editable text in the locale's decimal separator: 123450 → "1234,50". */
export function minorToInput(minor: number, locale: string): string {
  const sign = minor < 0 ? '-' : '';
  const abs = Math.abs(minor);
  const separator = decimalSeparator(locale);
  return `${sign}${Math.floor(abs / 100)}${separator}${String(abs % 100).padStart(2, '0')}`;
}

export function decimalSeparator(locale: string): string {
  return (
    new Intl.NumberFormat(locale).formatToParts(1.5).find((part) => part.type === 'decimal')
      ?.value ?? ','
  );
}

export interface MoneyFormatOptions {
  /** "+12,00 €" for positive amounts, as credits are shown. */
  signed?: boolean;
  /** Compact notation for chart axes: "1,2 K €". */
  compact?: boolean;
}

const formatters = new Map<string, Intl.NumberFormat>();

/** Formats minor units in the locale, e.g. 243050 EUR it-IT → "2.430,50 €". */
export function formatMoney(
  minor: number,
  currency: string,
  locale: string,
  options: MoneyFormatOptions = {},
): string {
  const key = `${locale}|${currency}|${options.signed ? 1 : 0}|${options.compact ? 1 : 0}`;
  let formatter = formatters.get(key);
  if (!formatter) {
    formatter = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency,
      // Italian CLDR leaves 4-digit amounts ungrouped ("2430,50 €"); the app
      // groups them ("2.430,50"), and lists of amounts read better that way.
      useGrouping: 'always',
      signDisplay: options.signed ? 'exceptZero' : 'auto',
      ...(options.compact ? { notation: 'compact', maximumFractionDigits: 1 } : {}),
    });
    formatters.set(key, formatter);
  }
  // Display only: the division never feeds back into stored amounts.
  return formatter.format(minor / 100);
}
