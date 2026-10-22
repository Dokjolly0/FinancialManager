import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The optional Hugging Face token for gated model repositories, in the
/// Keystore. It belongs to the phone, not the account, and is sent only to
/// huggingface.co (see ModelDownloader).
class HuggingFaceTokenStore {
  HuggingFaceTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'ai.huggingface_token';

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) async {
    final t = token.trim();
    if (t.isEmpty) return clear();
    await _storage.write(key: _key, value: t);
  }

  Future<void> clear() => _storage.delete(key: _key);
}
