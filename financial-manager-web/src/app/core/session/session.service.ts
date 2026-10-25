import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api } from '../api/api';
import { RefreshNetworkError, TokenStore } from '../auth/token-store';
import { LocaleService } from '../formatting/locale.service';
import { languageOf } from '../i18n/i18n';
import { ThemeService } from '../theme/theme.service';
import { AuthResponse, GoogleRegistrationRequired, UserProfile } from './user-profile';

/** Coarse session state the guards route on (plan.md section 9.8). */
export type SessionStatus = 'checking' | 'unauthenticated' | 'authenticated' | 'profileIncomplete';

/**
 * The signed-in user and the session lifecycle: restore at startup from the
 * stored refresh token (plan.md section 7.1), sign-in after register/login,
 * sign-out. Also applies the profile's language and theme.
 *
 * Signing out reloads the page on /login: every cache in memory belongs to
 * the previous account, and a fresh document is the one way to be sure none
 * of it survives (the app invalidates its user-scoped providers instead).
 */
@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly http = inject(HttpClient);
  private readonly tokens = inject(TokenStore);
  private readonly locale = inject(LocaleService);
  private readonly theme = inject(ThemeService);

  private readonly state = signal<SessionStatus>('checking');
  private readonly user = signal<UserProfile | null>(null);

  readonly status = this.state.asReadonly();
  readonly profile = this.user.asReadonly();
  readonly aiEnabled = computed(() => this.user()?.ai_enabled ?? true);

  /** Ticket and prefill between Google sign-in and the completion form (section 7.4). */
  readonly pendingGoogle = signal<GoogleRegistrationRequired | null>(null);

  constructor() {
    this.tokens.expired.subscribe(() => this.leave(true));
  }

  /** Runs once before the first navigation (provideAppInitializer). */
  async restore(): Promise<void> {
    if (!this.tokens.hasStoredSession()) {
      this.state.set('unauthenticated');
      return;
    }
    try {
      const token = await this.tokens.refresh();
      if (token === null) {
        this.tokens.clear();
        this.state.set('unauthenticated');
        return;
      }
      this.signIn(await this.fetchProfile());
    } catch (error) {
      // Offline at startup: keep the stored token, a reload tries again.
      if (!(error instanceof RefreshNetworkError)) this.tokens.clear();
      this.state.set('unauthenticated');
    }
  }

  /** Stores the tokens of an auth response and loads the profile. */
  async completeSignIn(response: AuthResponse): Promise<void> {
    this.tokens.applyTokens(response);
    this.pendingGoogle.set(null);
    this.signIn(await this.fetchProfile());
  }

  requireGoogleCompletion(pending: GoogleRegistrationRequired): void {
    this.pendingGoogle.set(pending);
    this.state.set('profileIncomplete');
  }

  cancelGoogleCompletion(): void {
    this.pendingGoogle.set(null);
    this.state.set('unauthenticated');
  }

  /** Replaces the profile after a PATCH /me, re-applying language and theme. */
  updateProfile(profile: UserProfile): void {
    this.user.set(profile);
    this.applyPreferences(profile);
  }

  async reloadProfile(): Promise<void> {
    this.updateProfile(await this.fetchProfile());
  }

  /** Signs out on the server (best effort) and here, then reloads on /login. */
  async signOut(everywhere = false): Promise<void> {
    try {
      await firstValueFrom(
        this.http.post(api(everywhere ? '/auth/logout-all' : '/auth/logout'), {}),
      );
    } catch {
      // The user asked to leave: forget the local session anyway.
    }
    disableGoogleAutoSelect();
    this.tokens.clear();
    this.leave(false);
  }

  private signIn(profile: UserProfile): void {
    this.updateProfile(profile);
    this.state.set('authenticated');
  }

  private applyPreferences(profile: UserProfile): void {
    this.locale.use(languageOf(profile.locale));
    this.theme.preference.set(profile.theme);
  }

  private fetchProfile(): Promise<UserProfile> {
    return firstValueFrom(this.http.get<UserProfile>(api('/me')));
  }

  /** Full reload on /login, keeping where the user was when the session expired. */
  private leave(keepLocation: boolean): void {
    const here = location.pathname + location.search;
    const from =
      keepLocation && here.startsWith('/app/') ? `?from=${encodeURIComponent(here)}` : '';
    location.replace(`/login${from}`);
  }
}

/** Stops Google One Tap from signing the user straight back in. */
function disableGoogleAutoSelect(): void {
  const google = (window as { google?: { accounts?: { id?: { disableAutoSelect?: () => void } } } })
    .google;
  google?.accounts?.id?.disableAutoSelect?.();
}
