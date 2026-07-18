import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../features/authentication/data/providers.dart';
import 'current_user_provider.dart';
import 'session_controller.dart';

/// Runs once at app startup (plan.md section 7.1): wires
/// [SessionTokenStore.onExpired] to sign out the app-wide session, then
/// tries to restore a session from the stored refresh token. [SplashScreen]
/// watches this and the router redirects once [sessionControllerProvider]
/// reflects the outcome.
final sessionRestoreProvider = FutureProvider<void>((ref) async {
  final tokenStore = ref.watch(sessionTokenStoreProvider);
  tokenStore.onExpired = () =>
      ref.read(sessionControllerProvider.notifier).signOut();

  // Must never leave SessionController stuck at `checking`: any
  // unexpected failure (secure storage unavailable, network error) falls
  // back to unauthenticated so the router still has somewhere to go
  // instead of leaving the splash screen up forever.
  try {
    final authRepository = ref.watch(authRepositoryProvider);
    final user = await authRepository.tryRestoreSession();

    if (user == null) {
      ref.read(sessionControllerProvider.notifier).signOut();
      return;
    }

    ref.read(currentUserProvider.notifier).state = user;
    ref.read(sessionControllerProvider.notifier).signIn();
  } catch (_) {
    ref.read(sessionControllerProvider.notifier).signOut();
  }
});
