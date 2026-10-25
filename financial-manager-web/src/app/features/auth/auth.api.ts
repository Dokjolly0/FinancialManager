import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, idempotencyHeaders } from '../../core/api/api';
import { deviceInfo } from '../../core/session/device';
import { AuthResponse, GoogleRegistrationRequired } from '../../core/session/user-profile';

export interface RegisterBody {
  first_name: string;
  last_name: string;
  username: string;
  email: string;
  password: string;
  confirm_password: string;
  avatar_background_color: string;
  avatar_text_color: string;
  initial_balance_minor: number;
  currency: string;
  timezone: string;
  locale: string;
  accepted_terms: boolean;
}

export interface GoogleCompletionBody {
  ticket: string;
  username: string;
  password: string;
  confirm_password: string;
  avatar_background_color: string;
  avatar_text_color: string;
  initial_balance_minor: number;
  currency: string;
  timezone: string;
  locale: string;
  accepted_terms: boolean;
}

export type GoogleVerifyResponse =
  | ({ status: 'authenticated' } & AuthResponse)
  | ({ status: 'registration_required' } & GoogleRegistrationRequired);

/** /v1/auth/* (plan.md section 14.1). */
@Injectable({ providedIn: 'root' })
export class AuthApi {
  private readonly http = inject(HttpClient);

  login(usernameOrEmail: string, password: string): Promise<AuthResponse> {
    return firstValueFrom(
      this.http.post<AuthResponse>(api('/auth/login'), {
        username_or_email: usernameOrEmail,
        password,
        ...deviceInfo(),
      }),
    );
  }

  register(body: RegisterBody): Promise<AuthResponse> {
    return firstValueFrom(
      this.http.post<AuthResponse>(
        api('/auth/register'),
        { ...body, ...deviceInfo() },
        { headers: idempotencyHeaders() },
      ),
    );
  }

  googleVerify(idToken: string): Promise<GoogleVerifyResponse> {
    return firstValueFrom(
      this.http.post<GoogleVerifyResponse>(api('/auth/google/verify'), {
        id_token: idToken,
        ...deviceInfo(),
      }),
    );
  }

  completeGoogleRegistration(body: GoogleCompletionBody): Promise<AuthResponse> {
    return firstValueFrom(
      this.http.post<AuthResponse>(api('/auth/google/complete-registration'), {
        ...body,
        ...deviceInfo(),
      }),
    );
  }

  forgotPassword(email: string): Promise<unknown> {
    return firstValueFrom(this.http.post(api('/auth/password/forgot'), { email }));
  }

  resetPassword(token: string, newPassword: string): Promise<unknown> {
    return firstValueFrom(
      this.http.post(api('/auth/password/reset'), { token, new_password: newPassword }),
    );
  }

  verifyEmail(token: string): Promise<unknown> {
    return firstValueFrom(this.http.post(api('/auth/email/verify'), { token }));
  }

  resendVerification(): Promise<unknown> {
    return firstValueFrom(this.http.post(api('/auth/email/resend-verification'), {}));
  }
}

/** Avatar backgrounds offered at registration (the app's _avatarColorChoices). */
export const AVATAR_COLORS = ['#176B5B', '#175CD3', '#B54708', '#B42318', '#6941C6'];
export const AVATAR_TEXT_COLOR = '#FFFFFF';
