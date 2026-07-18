/// Backend base URL per environment (plan.md section 9.5). The dev URL
/// matches the fixed host port from section 21.3 (API `10003`). Staging and
/// production URLs are placeholders until those environments are
/// provisioned — set via `--dart-define=API_BASE_URL=...` at build time
/// rather than hardcoding a real deployment URL here.
enum ApiEnvironment {
  local,
  staging,
  production;

  String get defaultBaseUrl => switch (this) {
    // 10.0.2.2 is the Android emulator's alias for the host loopback.
    // Running on iOS simulator or a physical device needs an explicit
    // --dart-define=API_BASE_URL=http://<host-ip>:10003/v1 override.
    ApiEnvironment.local => 'http://10.0.2.2:10003/v1',
    ApiEnvironment.staging => 'https://staging.example.invalid/v1',
    ApiEnvironment.production => 'https://api.example.invalid/v1',
  };

  /// Resolves the base URL for the current build: an explicit
  /// `--dart-define=API_BASE_URL=...` always wins, otherwise falls back to
  /// [defaultBaseUrl].
  String resolveBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    return override.isEmpty ? defaultBaseUrl : override;
  }
}
