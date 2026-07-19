/// Backend base URL per environment (plan.md section 9.5). Production points
/// at the self-hosted backend; `--dart-define=API_BASE_URL=...` can still
/// override the URL for emergency reroutes or local testing.
enum ApiEnvironment {
  local,
  staging,
  production;

  static ApiEnvironment get fromBuildConfig {
    const configuredEnvironment = String.fromEnvironment(
      'API_ENVIRONMENT',
      defaultValue: 'production',
    );
    return switch (configuredEnvironment) {
      'local' => ApiEnvironment.local,
      'staging' => ApiEnvironment.staging,
      'production' => ApiEnvironment.production,
      _ => ApiEnvironment.production,
    };
  }

  String get defaultBaseUrl => switch (this) {
    // 10.0.2.2 is the Android emulator's alias for the host loopback.
    // Running on iOS simulator or a physical device can use
    // --dart-define=API_ENVIRONMENT=local or API_BASE_URL to override.
    ApiEnvironment.local => 'http://10.0.2.2:10003/v1',
    ApiEnvironment.staging => 'https://staging.example.invalid/v1',
    ApiEnvironment.production => 'http://83.228.246.84:10003/v1',
  };

  /// Resolves the base URL for the current build: an explicit
  /// `--dart-define=API_BASE_URL=...` always wins, otherwise falls back to
  /// [defaultBaseUrl].
  String resolveBaseUrl() {
    const override = String.fromEnvironment('API_BASE_URL');
    return override.isEmpty ? defaultBaseUrl : override;
  }
}
