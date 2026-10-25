import { EnvironmentProviders, Provider, importProvidersFrom } from '@angular/core';
import {
  Translation,
  TranslocoTestingModule,
  provideTranslocoTranspiler,
} from '@jsverse/transloco';

import { IcuTranspiler } from '../app/core/i18n/icu-transpiler';

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
    provideTranslocoTranspiler(IcuTranspiler),
  ];
}
