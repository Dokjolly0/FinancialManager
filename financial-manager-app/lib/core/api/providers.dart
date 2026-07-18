import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_token_store.dart';
import 'api_client.dart';
import 'api_environment.dart';

/// The environment is fixed at [ApiEnvironment.local] for now — there is no
/// build flavor plumbing yet to pick staging/production, and both remain
/// placeholder URLs until those environments exist (plan.md section 9.5).
final apiEnvironmentProvider = Provider<ApiEnvironment>(
  (ref) => ApiEnvironment.local,
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
