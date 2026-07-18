import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_status.dart';

/// Holds the app-wide session state the router redirects on. The
/// authentication feature will call [signIn]/[requireProfileCompletion]/
/// [signOut] once it exists (Fase 2); for now nothing calls them yet, so
/// the app always starts unauthenticated and shows the login placeholder.
///
/// Session restoration at startup (plan.md section 7.1: read the stored
/// refresh token, attempt a refresh, load the profile) belongs here too,
/// added alongside the auth feature rather than faked now.
class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() => SessionStatus.unauthenticated;

  void signIn() => state = SessionStatus.authenticated;

  void requireProfileCompletion() => state = SessionStatus.profileIncomplete;

  void completeProfile() => state = SessionStatus.authenticated;

  void signOut() => state = SessionStatus.unauthenticated;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionStatus>(SessionController.new);
