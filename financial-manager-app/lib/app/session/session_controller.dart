import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/domain/models/auth_user.dart';
import 'current_user_provider.dart';
import 'session_status.dart';
import 'user_scoped_providers.dart';

/// Holds the app-wide session state the router redirects on. Starts at
/// [SessionStatus.checking] — [SplashScreen] watching
/// `sessionRestoreProvider` (plan.md section 7.1) resolves it to
/// authenticated or unauthenticated shortly after app start. The
/// authentication feature calls [signIn]/[signOut] on login/register/logout.
class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() => SessionStatus.checking;

  /// Called on successful login, registration, Google sign-in, and session
  /// restore. Sets the current user and clears every previously cached
  /// per-account provider, so a session switch can never leak stale data
  /// from the prior account (see user_scoped_providers.dart).
  void signIn(AuthUser user) {
    invalidateUserScopedProviders(ref);
    ref.read(currentUserProvider.notifier).state = user;
    state = SessionStatus.authenticated;
  }

  void requireProfileCompletion() => state = SessionStatus.profileIncomplete;

  void completeProfile() => state = SessionStatus.authenticated;

  void signOut() {
    invalidateUserScopedProviders(ref);
    ref.read(currentUserProvider.notifier).state = null;
    state = SessionStatus.unauthenticated;
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionStatus>(SessionController.new);
