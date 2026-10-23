/** GET/PATCH /v1/me (plan.md sections 7.13, 14.2), as the API sends it. */
export interface UserProfile {
  id: string;
  first_name: string;
  last_name: string;
  username: string;
  email: string;
  email_verified: boolean;
  avatar_mode: string;
  avatar_media_id?: string | null;
  avatar_background_color: string;
  avatar_text_color: string;
  locale: string;
  timezone: string;
  theme: ThemePreference;
  balance_hidden_default: boolean;
  first_day_of_week: 'monday' | 'sunday';
  /** Shows the AI analysis features (plan.md section 32.10). */
  ai_enabled: boolean;
  version: number;
  created_at: string;
}

export type ThemePreference = 'system' | 'light' | 'dark';

/** Response of register, login, Google sign-in and completion. */
export interface AuthResponse {
  access_token: string;
  refresh_token: string;
}

/** POST /auth/google/verify when the Google account has no user yet (plan.md section 7.4). */
export interface GoogleRegistrationRequired {
  ticket: string;
  email: string;
  email_verified: boolean;
  suggested_first_name: string;
  suggested_last_name: string;
}
