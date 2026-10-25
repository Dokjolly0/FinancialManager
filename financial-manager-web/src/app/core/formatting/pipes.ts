import { Pipe, PipeTransform, inject } from '@angular/core';

import { DateStyle, formatDate } from './dates';
import { LocaleService } from './locale.service';
import { MoneyFormatOptions, formatMoney } from './money';

/**
 * `{{ 1234 | money }}` → "12,34 €". Impure so a language switch reformats
 * at once; the Intl formatters behind it are cached.
 */
@Pipe({ name: 'money', pure: false })
export class MoneyPipe implements PipeTransform {
  private readonly locale = inject(LocaleService);

  transform(
    minor: number | null | undefined,
    currency = 'EUR',
    options?: MoneyFormatOptions,
  ): string {
    if (minor === null || minor === undefined) return '';
    return formatMoney(minor, currency, this.locale.intl(), options);
  }
}

/** `{{ iso | appDate: 'dateTime' }}` in the active language. */
@Pipe({ name: 'appDate', pure: false })
export class AppDatePipe implements PipeTransform {
  private readonly locale = inject(LocaleService);

  transform(value: string | Date | null | undefined, style: DateStyle = 'date'): string {
    if (value === null || value === undefined || value === '') return '';
    return formatDate(value, style, this.locale.intl());
  }
}

/** `{{ [a, b, c] | joinParts }}` → "a · c" when b is empty. */
@Pipe({ name: 'joinParts' })
export class JoinPartsPipe implements PipeTransform {
  transform(parts: (string | null | undefined)[], separator = ' · '): string {
    return parts.filter((part) => !!part && part.trim() !== '').join(separator);
  }
}

/** `{{ 73.12 | percent }}` → "73,1%" in Italian: a percentage (0-100) in the active locale. */
@Pipe({ name: 'percent', pure: false })
export class PercentPipe implements PipeTransform {
  private readonly locale = inject(LocaleService);

  transform(value: number | null | undefined, digits = 1): string {
    if (value === null || value === undefined) return '';
    return new Intl.NumberFormat(this.locale.intl(), {
      style: 'percent',
      minimumFractionDigits: digits,
      maximumFractionDigits: digits,
    }).format(value / 100);
  }
}
