import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

import { api } from '../api/api';

export const REFRESH_TOKEN_KEY = 'fm.refresh_token';
const REFRESH_LOCK = 'fm.refresh';

/** The refresh request could not reach the server: the session is still valid. */
export class RefreshNetworkError extends Error {
  constructor() {
    super('refresh: network error');
  }
}

interface TokenPair {
  access_token: string;
  refresh_token: string;
}

/**
 * Holds the access token in memory and the refresh token in localStorage
 * (the app's SessionTokenStore, plan.md section 15.6).
 *
 * The backend rotates the refresh token on every refresh and, if an old one
 * is presented again, revokes all the user's sessions as a replay. With the
 * dashboard open in several tabs each tab refreshes on its own, so refreshes
 * are serialized across tabs with the Web Locks API and the stored token is
 * read inside the lock: a tab waiting for the lock uses the token the other
 * tab just stored, never the one it rotated away. Within a tab, concurrent
 * 401s share one in-flight refresh.
 */
@Injectable({ providedIn: 'root' })
export class TokenStore {
  private access: string | null = null;
  private inFlight: Promise<string | null> | null = null;

  /** Emits when the session is gone: refresh rejected, or another tab signed out. */
  readonly expired = new Subject<void>();

  constructor() {
    // Another tab signed out (or its session expired): the stored token is gone.
    window.addEventListener('storage', (event) => {
      if (event.key === REFRESH_TOKEN_KEY && event.newValue === null && this.access !== null) {
        this.access = null;
        this.expired.next();
      }
    });
  }

  get accessToken(): string | null {
    return this.access;
  }

  /** True if a refresh token is stored: a session worth restoring at startup. */
  hasStoredSession(): boolean {
    return readStored() !== null;
  }

  /** Stores a freshly issued pair (register, login, Google sign-in). */
  applyTokens(pair: TokenPair): void {
    this.access = pair.access_token;
    writeStored(pair.refresh_token);
  }

  clear(): void {
    this.access = null;
    writeStored(null);
  }

  /**
   * A new access token, or null if the server rejected the refresh token
   * (the session is over). Throws RefreshNetworkError when the server can't
   * be reached, so a flaky connection doesn't sign the user out.
   */
  refresh(): Promise<string | null> {
    this.inFlight ??= withLock(() => this.doRefresh()).finally(() => (this.inFlight = null));
    return this.inFlight;
  }

  /** Clears the session and notifies the app (the router goes to /login). */
  expire(): void {
    this.clear();
    this.expired.next();
  }

  private async doRefresh(): Promise<string | null> {
    const refreshToken = readStored();
    if (refreshToken === null) return null;
    let response: Response;
    try {
      // Plain fetch, not HttpClient: the interceptors would attach the
      // expired access token and could recurse into this refresh on a 401.
      response = await fetch(api('/auth/refresh'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Request-Id': crypto.randomUUID() },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
    } catch {
      throw new RefreshNetworkError();
    }
    if (response.status >= 500) throw new RefreshNetworkError();
    if (!response.ok) return null;
    const pair = (await response.json()) as TokenPair;
    this.applyTokens(pair);
    return pair.access_token;
  }
}

function withLock<T>(task: () => Promise<T>): Promise<T> {
  const locks = (navigator as Navigator & { locks?: LockManager }).locks;
  return locks ? locks.request(REFRESH_LOCK, task) : task();
}

function readStored(): string | null {
  try {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
  } catch {
    return null;
  }
}

function writeStored(value: string | null): void {
  try {
    if (value === null) localStorage.removeItem(REFRESH_TOKEN_KEY);
    else localStorage.setItem(REFRESH_TOKEN_KEY, value);
  } catch {
    // Storage blocked (private mode, site data off): the session lasts
    // until the tab is closed.
  }
}
