import { Injectable, computed, inject, signal } from '@angular/core';
import { TranslocoService } from '@jsverse/transloco';

import { INTL_LOCALES, Language, browserLanguage } from '../i18n/i18n';

/** The active language and its Intl locale, for formatting amounts and dates. */
@Injectable({ providedIn: 'root' })
export class LocaleService {
  private readonly transloco = inject(TranslocoService);
  private readonly current = signal<Language>(browserLanguage());

  readonly language = this.current.asReadonly();
  readonly intl = computed(() => INTL_LOCALES[this.current()]);

  constructor() {
    this.apply(this.current());
  }

  use(language: Language): void {
    this.current.set(language);
    this.apply(language);
  }

  private apply(language: Language): void {
    this.transloco.setActiveLang(language);
    document.documentElement.lang = language;
  }
}
