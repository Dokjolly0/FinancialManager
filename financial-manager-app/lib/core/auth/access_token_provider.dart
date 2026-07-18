/// Seam between the networking layer and the authentication feature (not
/// yet implemented — lands in Fase 2 of plan.md's roadmap). The API client
/// depends only on this interface so it can be built and tested now; the
/// auth feature provides the real implementation later without the
/// networking code changing.
abstract class AccessTokenProvider {
  /// The current in-memory access token, or null if signed out. Access
  /// tokens are never persisted to disk (plan.md section 15.6) — only the
  /// refresh token is stored securely.
  String? get currentAccessToken;

  /// Attempts to obtain a new access token using the stored refresh token.
  /// Concurrent callers must be coalesced into a single network call
  /// (plan.md section 9.5: "refresh token serializzato, evitando richieste
  /// refresh concorrenti") — that serialization is the implementation's
  /// responsibility, not the caller's.
  ///
  /// Returns the new access token, or null if refresh failed (expired,
  /// revoked, or reused refresh token).
  Future<String?> refreshAccessToken();

  /// Called when refresh fails and the session cannot be recovered. The
  /// implementation should clear local session state; the router reacts by
  /// redirecting to login (plan.md section 9.8).
  Future<void> onSessionExpired();
}

/// Placeholder used before the auth feature exists: always signed out,
/// refresh always fails. Lets the API client and its tests run today.
class NoopAccessTokenProvider implements AccessTokenProvider {
  const NoopAccessTokenProvider();

  @override
  String? get currentAccessToken => null;

  @override
  Future<String?> refreshAccessToken() async => null;

  @override
  Future<void> onSessionExpired() async {}
}
