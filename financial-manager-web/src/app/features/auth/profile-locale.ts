import { Language } from '../../core/i18n/i18n';

/**
 * Profile locales the app offers (account_preferences_screen.dart:
 * it-IT, en-US); new accounts get the one of the language in use.
 */
export const PROFILE_LOCALES: { value: string; label: string; language: Language }[] = [
  { value: 'it-IT', label: 'Italiano', language: 'it' },
  { value: 'en-US', label: 'English', language: 'en' },
];

export function profileLocale(language: Language): string {
  return PROFILE_LOCALES.find((locale) => locale.language === language)?.value ?? 'it-IT';
}
