import { Injectable, computed, effect, signal } from '@angular/core';

import { ThemePreference } from '../session/user-profile';

/**
 * Applies the profile's theme (system, light or dark; plan.md section 7.13)
 * as a `light`/`dark` class on <html>, which the Tailwind tokens in
 * styles.css follow. "system" tracks the OS setting live.
 */
@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly media = window.matchMedia('(prefers-color-scheme: dark)');
  private readonly systemDark = signal(this.media.matches);

  readonly preference = signal<ThemePreference>('system');
  readonly dark = computed(() =>
    this.preference() === 'system' ? this.systemDark() : this.preference() === 'dark',
  );

  constructor() {
    this.media.addEventListener('change', (event) => this.systemDark.set(event.matches));
    effect(() => {
      const root = document.documentElement;
      root.classList.toggle('dark', this.dark());
      root.classList.toggle('light', !this.dark());
    });
  }
}
