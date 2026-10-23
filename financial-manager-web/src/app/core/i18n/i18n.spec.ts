import { browserLanguage, languageOf } from './i18n';

describe('i18n languages', () => {
  it('picks the first supported browser language', () => {
    expect(browserLanguage(['fr-FR', 'it-IT', 'en-US'])).toBe('it');
    expect(browserLanguage(['en-US'])).toBe('en');
  });

  it('falls back to English like the app', () => {
    expect(browserLanguage(['de-DE'])).toBe('en');
    expect(browserLanguage([])).toBe('en');
  });

  it('reads the language of a profile locale', () => {
    expect(languageOf('it-IT')).toBe('it');
    expect(languageOf('en')).toBe('en');
    expect(languageOf('es')).toBe('en');
    expect(languageOf(null)).toBe('en');
  });
});
