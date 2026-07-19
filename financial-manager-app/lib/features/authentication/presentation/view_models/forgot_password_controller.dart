import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';

class ForgotPasswordState {
  const ForgotPasswordState({
    this.isSubmitting = false,
    this.error,
    this.succeeded = false,
  });

  final bool isSubmitting;
  final AppError? error;
  final bool succeeded;

  ForgotPasswordState copyWith({
    bool? isSubmitting,
    AppError? error,
    bool? succeeded,
  }) {
    return ForgotPasswordState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      succeeded: succeeded ?? this.succeeded,
    );
  }
}

class ForgotPasswordController extends Notifier<ForgotPasswordState> {
  @override
  ForgotPasswordState build() => const ForgotPasswordState();

  Future<void> submit(String email) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      state = state.copyWith(isSubmitting: false, succeeded: true);
    } on AppError catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final forgotPasswordControllerProvider =
    NotifierProvider<ForgotPasswordController, ForgotPasswordState>(
      ForgotPasswordController.new,
    );
