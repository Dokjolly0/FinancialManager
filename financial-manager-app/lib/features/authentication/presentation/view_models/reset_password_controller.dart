import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../app/session/session_status.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';

class ResetPasswordState {
  const ResetPasswordState({
    this.isSubmitting = false,
    this.error,
    this.succeeded = false,
  });

  final bool isSubmitting;
  final AppError? error;
  final bool succeeded;

  /// The link was already used or is past its 30 minutes: the form can't
  /// help, only a new link can.
  bool get linkExpired =>
      error is DomainError &&
      (error! as DomainError).code == 'INVALID_OR_EXPIRED_TOKEN';

  ResetPasswordState copyWith({
    bool? isSubmitting,
    AppError? error,
    bool? succeeded,
  }) {
    return ResetPasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      succeeded: succeeded ?? this.succeeded,
    );
  }
}

/// Sets a new password from the link in the "forgot password" email
/// (`/reset-password?token=...`, plan.md section 15.5).
class ResetPasswordController extends Notifier<ResetPasswordState> {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  Future<void> submit({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: token, newPassword: newPassword);
      // The backend revokes every session on reset: a session open in
      // this browser or app is dead too, so drop it locally.
      if (ref.read(sessionControllerProvider) !=
          SessionStatus.unauthenticated) {
        await ref.read(authRepositoryProvider).logout();
        ref.read(sessionControllerProvider.notifier).signOut();
      }
      state = state.copyWith(isSubmitting: false, succeeded: true);
    } on AppError catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, ResetPasswordState>(
      ResetPasswordController.new,
    );
