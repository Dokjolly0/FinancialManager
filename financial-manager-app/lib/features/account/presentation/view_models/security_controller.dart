import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../state/security_state.dart';

/// Sicurezza (plan.md section 7.13): sessioni attive, con revoca singola.
class SecurityController extends Notifier<SecurityState> {
  @override
  SecurityState build() {
    Future.microtask(refresh);
    return const SecurityState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final sessions = await ref.read(accountRepositoryProvider).listSessions();
      state = state.copyWith(isLoading: false, sessions: sessions);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> revoke(String sessionId) async {
    try {
      await ref.read(accountRepositoryProvider).revokeSession(sessionId);
      state = state.copyWith(
        sessions: state.sessions.where((s) => s.id != sessionId).toList(),
      );
    } on AppError catch (_) {
      // Refresh to reconcile rather than guessing what happened.
      refresh();
    }
  }
}

final securityControllerProvider =
    NotifierProvider<SecurityController, SecurityState>(SecurityController.new);
