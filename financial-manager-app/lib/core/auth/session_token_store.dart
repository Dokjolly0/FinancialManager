import 'package:dio/dio.dart';

import '../api/api_environment.dart';
import 'access_token_provider.dart';
import 'secure_session_storage.dart';

/// The real [AccessTokenProvider]: holds the access token in memory and the
/// refresh token in secure storage, and knows how to refresh (plan.md
/// section 15.6). Deliberately uses its own bare [Dio] instance (no
/// interceptors) for the refresh call itself — going through the main
/// networking [Dio] would attach an (expired) access token header for no
/// reason and risks recursing back into this same refresh logic on a 401.
///
/// The authentication feature calls [applyTokens] after a successful
/// register/login and [clear] after logout; everything else (the
/// interceptor calling [refreshAccessToken] on a 401) happens without the
/// feature layer involved at all. [onExpired] is wired by app startup to
/// flip the app-wide session state so the router redirects to login.
class SessionTokenStore implements AccessTokenProvider {
  SessionTokenStore({
    required ApiEnvironment environment,
    SecureSessionStorage? secureStorage,
    Dio? refreshDio,
  }) : _secureStorage = secureStorage ?? SecureSessionStorage(),
       _refreshDio =
           refreshDio ??
           Dio(BaseOptions(baseUrl: environment.resolveBaseUrl()));

  final SecureSessionStorage _secureStorage;
  final Dio _refreshDio;

  String? _accessToken;

  /// Invoked once the session is confirmed unrecoverable (plan.md section 9.8).
  void Function()? onExpired;

  @override
  String? get currentAccessToken => _accessToken;

  @override
  Future<String?> refreshAccessToken() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data!;
      _accessToken = data['access_token'] as String;
      await _secureStorage.writeRefreshToken(data['refresh_token'] as String);
      return _accessToken;
    } on DioException {
      return null;
    }
  }

  @override
  Future<void> onSessionExpired() async {
    await clear();
    onExpired?.call();
  }

  /// Persists a freshly issued token pair (from register or login).
  Future<void> applyTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    await _secureStorage.writeRefreshToken(refreshToken);
  }

  /// True if a refresh token is stored, i.e. there is a session worth
  /// trying to restore at startup (plan.md section 7.1).
  Future<bool> hasStoredSession() async {
    return (await _secureStorage.readRefreshToken()) != null;
  }

  Future<void> clear() async {
    _accessToken = null;
    await _secureStorage.clear();
  }
}
