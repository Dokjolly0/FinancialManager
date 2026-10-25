import { HttpClient } from '@angular/common/http';
import { EnvironmentProviders, Injectable, Provider, inject, isDevMode } from '@angular/core';
import {
  Translation,
  TranslocoLoader,
  provideTransloco,
  provideTranslocoTranspiler,
} from '@jsverse/transloco';

import { IcuTranspiler } from './icu-transpiler';

/** Languages of the dashboard: the same as the app's ARB files. */
export const LANGUAGES = ['it', 'en'] as const;
export type Language = (typeof LANGUAGES)[number];

/** Intl locale for each language: amounts, dates and plural rules. */
export const INTL_LOCALES: Record<Language, string> = { it: 'it-IT', en: 'en-GB' };

/**
 * Language before sign-in, from the browser's preferences. Like the app
 * (MaterialApp's resolution over AppLocalizations.supportedLocales), an
 * unsupported system language falls back to English.
 */
export function browserLanguage(languages: readonly string[] = navigator.languages): Language {
  for (const tag of languages) {
    const lang = tag.split('-')[0].toLowerCase();
    if ((LANGUAGES as readonly string[]).includes(lang)) return lang as Language;
  }
  return 'en';
}

/** Language of a profile locale such as "it-IT" or "en"; unknown values give English. */
export function languageOf(locale: string | null | undefined): Language {
  const lang = (locale ?? '').split('-')[0].toLowerCase();
  return (LANGUAGES as readonly string[]).includes(lang) ? (lang as Language) : 'en';
}

/** Loads public/i18n/<lang>.json, built from the ARB files (scripts/arb-to-json.mjs). */
@Injectable({ providedIn: 'root' })
export class TranslationLoader implements TranslocoLoader {
  private readonly http = inject(HttpClient);

  getTranslation(lang: string) {
    return this.http.get<Translation>(`i18n/${lang}.json`);
  }
}

export function provideI18n(): (Provider | EnvironmentProviders)[] {
  return [
    ...provideTransloco({
      config: {
        availableLangs: [...LANGUAGES],
        defaultLang: browserLanguage(),
        fallbackLang: 'it',
        reRenderOnLangChange: true,
        prodMode: !isDevMode(),
        missingHandler: { useFallbackTranslation: true, logMissingKey: isDevMode() },
      },
      loader: TranslationLoader,
    }),
    // ARB messages are ICU MessageFormat ({name}, plurals), formatted
    // without eval so the CSP can forbid it (icu-transpiler.ts).
    provideTranslocoTranspiler(IcuTranspiler),
  ];
}
