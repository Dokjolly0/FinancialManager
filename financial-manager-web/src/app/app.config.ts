import { provideHttpClient, withFetch, withInterceptors } from '@angular/common/http';
import {
  ApplicationConfig,
  inject,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
} from '@angular/core';
import { provideRouter, withComponentInputBinding, withInMemoryScrolling } from '@angular/router';
import { TranslocoService } from '@jsverse/transloco';
import { firstValueFrom } from 'rxjs';

import { routes } from './app.routes';
import { requestIdInterceptor } from './core/api/request-id.interceptor';
import { authInterceptor } from './core/auth/auth.interceptor';
import { provideI18n } from './core/i18n/i18n';
import { SessionService } from './core/session/session.service';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideHttpClient(withFetch(), withInterceptors([requestIdInterceptor, authInterceptor])),
    provideRouter(
      routes,
      withComponentInputBinding(),
      withInMemoryScrolling({ scrollPositionRestoration: 'enabled' }),
    ),
    ...provideI18n(),
    // Before the first navigation: restore the session (plan.md section 7.1),
    // which also picks the profile's language, then load that language so no
    // screen renders untranslated keys.
    provideAppInitializer(async () => {
      const session = inject(SessionService);
      const transloco = inject(TranslocoService);
      await session.restore();
      await firstValueFrom(transloco.load(transloco.getActiveLang()));
    }),
  ],
};
