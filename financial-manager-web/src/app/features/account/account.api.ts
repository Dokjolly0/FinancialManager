import { HttpClient, HttpResponse } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, resolveApiPath } from '../../core/api/api';
import { SessionService } from '../../core/session/session.service';
import { UserProfile } from '../../core/session/user-profile';

/** The editable part of the profile (PATCH /v1/me replaces it as a whole). */
export type ProfileFields = Pick<
  UserProfile,
  | 'first_name'
  | 'last_name'
  | 'timezone'
  | 'locale'
  | 'theme'
  | 'balance_hidden_default'
  | 'first_day_of_week'
  | 'ai_enabled'
>;

export interface AccountSession {
  id: string;
  device_name?: string | null;
  platform?: string | null;
  created_at: string;
  last_used_at: string;
  expires_at: string;
  is_current: boolean;
}

export interface LinkedIdentity {
  provider: string;
  linked_at: string;
  last_used_at?: string | null;
}

export interface ExportRecord {
  id: string;
  format: 'csv' | 'json';
  status: 'pending' | 'processing' | 'ready' | 'failed' | string;
  error_message?: string | null;
  download_url?: string | null;
  created_at: string;
}

/** /v1/me, sessions, identities and exports (plan.md sections 7.13, 14.2, 14.3, 20). */
@Injectable({ providedIn: 'root' })
export class AccountApi {
  private readonly http = inject(HttpClient);
  private readonly session = inject(SessionService);
  private saving: Promise<unknown> = Promise.resolve();

  /**
   * Saves profile changes on top of the current profile. PATCH /me uses
   * optimistic locking, so saves are queued: two quick changes would
   * otherwise send the same version and the second would conflict.
   */
  updateProfile(changes: Partial<ProfileFields>): Promise<UserProfile> {
    const run = this.saving.then(async () => {
      const current = this.session.profile();
      if (!current) throw new Error('not signed in');
      const body = {
        first_name: current.first_name,
        last_name: current.last_name,
        timezone: current.timezone,
        locale: current.locale,
        theme: current.theme,
        balance_hidden_default: current.balance_hidden_default,
        first_day_of_week: current.first_day_of_week,
        ai_enabled: current.ai_enabled,
        ...changes,
        version: current.version,
      };
      const profile = await firstValueFrom(this.http.patch<UserProfile>(api('/me'), body));
      this.session.updateProfile(profile);
      return profile;
    });
    this.saving = run.catch(() => undefined);
    return run;
  }

  changePassword(currentPassword: string, newPassword: string): Promise<unknown> {
    return firstValueFrom(
      this.http.post(api('/auth/password/change'), {
        current_password: currentPassword,
        new_password: newPassword,
        confirm_new_password: newPassword,
      }),
    );
  }

  async sessions(): Promise<AccountSession[]> {
    const response = await firstValueFrom(
      this.http.get<{ sessions: AccountSession[] | null }>(api('/me/sessions')),
    );
    return response.sessions ?? [];
  }

  revokeSession(id: string): Promise<unknown> {
    return firstValueFrom(this.http.delete(api(`/me/sessions/${id}`)));
  }

  async identities(): Promise<LinkedIdentity[]> {
    const response = await firstValueFrom(
      this.http.get<{ identities: LinkedIdentity[] | null }>(api('/me/identities')),
    );
    return response.identities ?? [];
  }

  linkGoogle(idToken: string, currentPassword: string): Promise<unknown> {
    return firstValueFrom(
      this.http.post(api('/me/identities/google/link'), {
        id_token: idToken,
        current_password: currentPassword,
      }),
    );
  }

  unlinkGoogle(): Promise<unknown> {
    return firstValueFrom(this.http.delete(api('/me/identities/google')));
  }

  requestExport(format: 'csv' | 'json'): Promise<ExportRecord> {
    return firstValueFrom(this.http.post<ExportRecord>(api('/me/export'), { format }));
  }

  getExport(id: string): Promise<ExportRecord> {
    return firstValueFrom(this.http.get<ExportRecord>(api(`/me/export/${id}`)));
  }

  /** The export file, with its name from Content-Disposition when sent. */
  async downloadExport(record: ExportRecord): Promise<HttpResponse<Blob>> {
    const url = record.download_url
      ? resolveApiPath(record.download_url)
      : api(`/me/export/${record.id}/download`);
    return firstValueFrom(this.http.get(url, { responseType: 'blob', observe: 'response' }));
  }

  /** Deletes the account; the password may be empty for Google-only accounts. */
  deleteAccount(currentPassword: string | null): Promise<unknown> {
    return firstValueFrom(
      this.http.delete(api('/me'), {
        body: currentPassword ? { current_password: currentPassword } : {},
      }),
    );
  }
}
