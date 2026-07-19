import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../authentication/data/providers.dart' show googleSignInServiceProvider;
import '../domain/repositories/account_repository.dart';
import 'repositories/account_repository_impl.dart';
import 'services/account_api.dart';

final accountApiProvider = Provider<AccountApi>((ref) {
  return AccountApi(ref.watch(apiClientProvider).dio);
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(
    ref.watch(accountApiProvider),
    ref.watch(apiClientProvider).dio,
    ref.watch(sessionTokenStoreProvider),
    ref.watch(googleSignInServiceProvider),
  );
});
