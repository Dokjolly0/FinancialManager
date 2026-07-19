import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/current_user_provider.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../../domain/models/google_sign_in_outcome.dart';

class GoogleSignInState {
  const GoogleSignInState({this.isSubmitting = false, this.error});

  final bool isSubmitting;
  final AppError? error;

  GoogleSignInState copyWith({bool? isSubmitting, AppError? error}) {
    return GoogleSignInState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

/// Drives the "Continua con Google" button (plan.md section 7.2/8.2).
/// On [GoogleSignInAuthenticated] it updates the app-wide session directly
/// (same as login); on [GoogleSignInRegistrationRequired] it stores the
/// pending ticket for the completion screen and returns it so the caller
/// can navigate; on cancellation it does nothing.
class GoogleSignInController extends Notifier<GoogleSignInState> {
  @override
  GoogleSignInState build() => const GoogleSignInState();

  Future<GoogleSignInOutcome?> signIn() async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final outcome = await ref.read(authRepositoryProvider).signInWithGoogle();

      switch (outcome) {
        case GoogleSignInAuthenticated(:final user):
          ref.read(currentUserProvider.notifier).state = user;
          ref.read(sessionControllerProvider.notifier).signIn();
        case GoogleSignInRegistrationRequired():
          break;
        case GoogleSignInCancelledByUser():
          break;
      }

      state = state.copyWith(isSubmitting: false);
      return outcome;
    } on AppError catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }
}

final googleSignInControllerProvider =
    NotifierProvider<GoogleSignInController, GoogleSignInState>(
      GoogleSignInController.new,
    );
