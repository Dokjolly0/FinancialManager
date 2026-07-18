import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps Keychain (iOS) / Keystore (Android) via [FlutterSecureStorage] for
/// the one piece of session state that must survive app restarts: the
/// refresh token (plan.md section 9.2, section 15.6). The access token is
/// intentionally not covered here — it lives in memory only, via whatever
/// implements [AccessTokenProvider].
class SecureSessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _refreshTokenKey = 'auth.refresh_token';

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshTokenKey);
}
