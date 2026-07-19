import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_token_store.dart';
import 'api_client.dart';
import 'api_environment.dart';

/// Defaults to production, while still allowing local/staging builds via
/// `--dart-define=API_ENVIRONMENT=local` or an explicit API_BASE_URL override.
final apiEnvironmentProvider = Provider<ApiEnvironment>(
  (ref) => ApiEnvironment.fromBuildConfig,
);

final sessionTokenStoreProvider = Provider<SessionTokenStore>((ref) {
  return SessionTokenStore(environment: ref.watch(apiEnvironmentProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    environment: ref.watch(apiEnvironmentProvider),
    tokenProvider: ref.watch(sessionTokenStoreProvider),
  );
});
