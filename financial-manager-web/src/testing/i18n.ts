import { EnvironmentProviders, Provider, importProvidersFrom } from '@angular/core';
import { Translation, TranslocoTestingModule } from '@jsverse/transloco';
import { provideTranslocoMessageformat } from '@jsverse/transloco-messageformat';

/**
 * Transloco for component tests: synchronous, in English, with the given
 * messages (keys missing from them render as the key itself).
 */
export function provideTestI18n(en: Translation = {}): (Provider | EnvironmentProviders)[] {
  return [
    importProvidersFrom(
      TranslocoTestingModule.forRoot({
        langs: { en, it: {} },
        translocoConfig: { availableLangs: ['en', 'it'], defaultLang: 'en' },
        preloadLangs: true,
      }),
    ),
    provideTranslocoMessageformat(),
  ];
}
