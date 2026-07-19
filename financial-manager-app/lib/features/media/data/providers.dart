import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/repositories/media_repository.dart';
import 'repositories/media_repository_impl.dart';
import 'services/media_api.dart';

final mediaApiProvider = Provider<MediaApi>((ref) {
  return MediaApi(ref.watch(apiClientProvider).dio);
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(
    ref.watch(mediaApiProvider),
    ref.watch(apiClientProvider).dio,
    ref.watch(sessionTokenStoreProvider),
  );
});
