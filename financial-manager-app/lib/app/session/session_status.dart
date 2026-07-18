/// Coarse authentication state the router redirects on (plan.md section
/// 9.8). The authentication feature (Fase 2 of the roadmap) is what
/// actually transitions this state after checking the stored refresh token
/// and calling the backend; until then it starts and stays
/// [SessionStatus.unauthenticated].
enum SessionStatus {
  /// Still restoring the session at app startup (plan.md section 7.1).
  checking,

  /// No valid session; user must sign in.
  unauthenticated,

  /// Signed in with a complete profile.
  authenticated,

  /// Signed in via Google but the mandatory profile fields (username,
  /// wallet, currency, ...) are not filled yet (plan.md section 7.4).
  profileIncomplete,
}
