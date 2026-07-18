import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_status.dart';

/// Holds the app-wide session state the router redirects on. Starts at
/// [SessionStatus.checking] — [SplashScreen] watching
/// `sessionRestoreProvider` (plan.md section 7.1) resolves it to
/// authenticated or unauthenticated shortly after app start. The
/// authentication feature calls [signIn]/[signOut] on login/register/logout.
class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() => SessionStatus.checking;

  void signIn() => state = SessionStatus.authenticated;

  void requireProfileCompletion() => state = SessionStatus.profileIncomplete;

  void completeProfile() => state = SessionStatus.authenticated;

  void signOut() => state = SessionStatus.unauthenticated;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionStatus>(SessionController.new);
