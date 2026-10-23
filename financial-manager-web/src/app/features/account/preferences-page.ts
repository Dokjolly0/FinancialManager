import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';

import { ErrorText } from '../../core/errors/error-text';
import { SessionService } from '../../core/session/session.service';
import { ThemePreference } from '../../core/session/user-profile';
import { SegmentOption, Segmented, Switch } from '../../shared/ui/form-controls';
import { PageHeader } from '../../shared/ui/page-header';
import { Toasts } from '../../shared/ui/toast';
import { PROFILE_LOCALES } from '../auth/profile-locale';
import { AccountApi, ProfileFields } from './account.api';

/** The app's short list, plus every zone the browser knows. */
const COMMON_TIMEZONES = [
  'Europe/Rome',
  'Europe/London',
  'America/New_York',
  'America/Los_Angeles',
  'Asia/Tokyo',
  'UTC',
];

/**
 * Preferences (plan.md section 7.13): theme, language, time zone, first
 * day of the week, hide balance on open, AI features. Each change is saved
 * at once; saves are queued so quick changes don't conflict.
 */
@Component({
  selector: 'app-preferences-page',
  imports: [FormsModule, PageHeader, Segmented, Switch, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'accountPreferencesMenuTitle' | transloco"
        back="/app/account"
        [backLabel]="'backAction' | transloco"
      />
      @if (session.profile(); as profile) {
        <section class="card card-pad space-y-6">
          <div>
            <p class="label">{{ 'themeLabel' | transloco }}</p>
            <app-segmented
              [options]="themes"
              [label]="'themeLabel' | transloco"
              [ngModel]="profile.theme"
              (ngModelChange)="save({ theme: $event })"
            />
          </div>
          <div class="grid gap-5 sm:grid-cols-2">
            <div>
              <label class="label" for="pref-lang">{{ 'languageLabel' | transloco }}</label>
              <select
                id="pref-lang"
                class="input"
                [ngModel]="localeValue(profile.locale)"
                (ngModelChange)="save({ locale: $event })"
              >
                @for (locale of locales; track locale.value) {
                  <option [value]="locale.value">{{ locale.label }}</option>
                }
              </select>
            </div>
            <div>
              <label class="label" for="pref-tz">{{ 'timezoneLabel' | transloco }}</label>
              <select
                id="pref-tz"
                class="input"
                [ngModel]="profile.timezone"
                (ngModelChange)="save({ timezone: $event })"
              >
                @for (zone of timezones(); track zone) {
                  <option [value]="zone">{{ zone.replaceAll('_', ' ') }}</option>
                }
              </select>
            </div>
          </div>
          <div>
            <p class="label">{{ 'firstDayOfWeekLabel' | transloco }}</p>
            <app-segmented
              [options]="weekdays"
              [stretch]="false"
              [label]="'firstDayOfWeekLabel' | transloco"
              [ngModel]="profile.first_day_of_week"
              (ngModelChange)="save({ first_day_of_week: $event })"
            />
          </div>
          <div class="space-y-4 border-t border-border pt-5">
            <app-switch
              [label]="'hideBalanceOnOpenTitle' | transloco"
              [description]="'hideBalanceOnOpenSubtitle' | transloco"
              [ngModel]="profile.balance_hidden_default"
              (ngModelChange)="save({ balance_hidden_default: $event })"
            />
            <app-switch
              [label]="'aiFeaturesSwitchTitle' | transloco"
              [description]="'aiFeaturesSwitchSubtitle' | transloco"
              [ngModel]="profile.ai_enabled"
              (ngModelChange)="save({ ai_enabled: $event })"
            />
          </div>
          @if (saving()) {
            <p class="hint text-right">{{ 'webSaving' | transloco }}</p>
          }
        </section>
      }
    </div>
  `,
})
export class PreferencesPage {
  protected readonly session = inject(SessionService);
  private readonly account = inject(AccountApi);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);

  protected readonly locales = PROFILE_LOCALES;
  protected readonly saving = signal(0);

  protected readonly themes: SegmentOption<ThemePreference>[] = [
    { value: 'system', labelKey: 'themeOptionSystem' },
    { value: 'light', labelKey: 'themeOptionLight' },
    { value: 'dark', labelKey: 'themeOptionDark' },
  ];
  protected readonly weekdays: SegmentOption<'monday' | 'sunday'>[] = [
    { value: 'monday', labelKey: 'weekdayMonday' },
    { value: 'sunday', labelKey: 'weekdaySunday' },
  ];
  protected readonly timezones = computed(() => {
    const current = this.session.profile()?.timezone;
    const all =
      (Intl as { supportedValuesOf?: (key: string) => string[] }).supportedValuesOf?.('timeZone') ??
      [];
    return [...new Set([...(current ? [current] : []), ...COMMON_TIMEZONES, ...all])];
  });

  /** An old profile locale ("it", "en-GB") shows as the matching option. */
  protected localeValue(locale: string): string {
    const language = locale.split('-')[0];
    return (
      PROFILE_LOCALES.find((l) => l.value === locale || l.language === language)?.value ?? 'it-IT'
    );
  }

  protected async save(changes: Partial<ProfileFields>): Promise<void> {
    this.saving.update((n) => n + 1);
    try {
      await this.account.updateProfile(changes);
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
      // Re-read the server's state so the controls show what is saved.
      void this.session.reloadProfile().catch(() => undefined);
    } finally {
      this.saving.update((n) => n - 1);
    }
  }
}
