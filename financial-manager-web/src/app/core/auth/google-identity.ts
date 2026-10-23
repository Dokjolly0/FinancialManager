import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

/**
 * The Web-application OAuth client the backend verifies ID tokens against
 * (GOOGLE_CLIENT_IDS), the same as the app's serverClientId in
 * lib/core/auth/google_sign_in_service.dart. Not a secret: OAuth client IDs
 * are meant to ship in clients. Its "Authorized JavaScript origins" must list
 * the dashboard's origins (docs/build-deploy.md).
 */
export const GOOGLE_CLIENT_ID =
  '394336083524-bulv3lv21sl2jl1gkrjnad25i7qvgv1v.apps.googleusercontent.com';

const SCRIPT_URL = 'https://accounts.google.com/gsi/client';

interface GoogleId {
  initialize(config: {
    client_id: string;
    callback: (response: { credential: string }) => void;
    auto_select?: boolean;
    cancel_on_tap_outside?: boolean;
    ux_mode?: 'popup' | 'redirect';
    use_fedcm_for_button?: boolean;
  }): void;
  renderButton(parent: HTMLElement, options: Record<string, unknown>): void;
  disableAutoSelect(): void;
}

declare global {
  interface Window {
    google?: { accounts?: { id?: GoogleId } };
  }
}

/**
 * Google Identity Services: the rendered "Continue with Google" button, the
 * only way to sign in with Google in a browser (plan.md section 15.2). The
 * script is loaded on first use (the CSP allows accounts.google.com/gsi);
 * the ID token of each sign-in arrives on `credentials`, for login or for
 * linking Google to the account.
 */
@Injectable({ providedIn: 'root' })
export class GoogleIdentity {
  private loading: Promise<GoogleId> | null = null;

  readonly credentials = new Subject<string>();

  /** Renders the button into `parent`; rejects if Google's script can't load. */
  async renderButton(parent: HTMLElement, locale: string, dark: boolean): Promise<void> {
    const id = await this.load();
    parent.replaceChildren();
    id.renderButton(parent, {
      type: 'standard',
      theme: dark ? 'filled_black' : 'outline',
      size: 'large',
      text: 'continue_with',
      shape: 'pill',
      logo_alignment: 'center',
      width: Math.min(parent.clientWidth || 360, 400),
      locale,
    });
  }

  private load(): Promise<GoogleId> {
    this.loading ??= new Promise<GoogleId>((resolve, reject) => {
      const ready = () => {
        const id = window.google?.accounts?.id;
        if (!id) {
          reject(new Error('Google Identity Services unavailable'));
          return;
        }
        id.initialize({
          client_id: GOOGLE_CLIENT_ID,
          callback: (response) => this.credentials.next(response.credential),
          auto_select: false,
          cancel_on_tap_outside: true,
          ux_mode: 'popup',
          use_fedcm_for_button: true,
        });
        resolve(id);
      };
      if (window.google?.accounts?.id) {
        ready();
        return;
      }
      const script = document.createElement('script');
      script.src = SCRIPT_URL;
      script.async = true;
      script.onload = ready;
      script.onerror = () => reject(new Error('Google Identity Services failed to load'));
      document.head.appendChild(script);
    }).catch((error: unknown) => {
      this.loading = null;
      throw error;
    });
    return this.loading;
  }
}
