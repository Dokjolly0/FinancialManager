import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/device_info_service.dart';
import '../../../core/auth/google_sign_in_service.dart';
import '../domain/repositories/auth_repository.dart';
import 'repositories/auth_repository_impl.dart';
import 'services/auth_api.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(apiClientProvider).dio);
});

final googleSignInServiceProvider = Provider<GoogleSignInService>((ref) {
  return GoogleSignInService();
});

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  return DeviceInfoService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    authApi: ref.watch(authApiProvider),
    tokenStore: ref.watch(sessionTokenStoreProvider),
    googleSignIn: ref.watch(googleSignInServiceProvider),
    deviceInfo: ref.watch(deviceInfoServiceProvider),
  );
});
