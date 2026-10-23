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
