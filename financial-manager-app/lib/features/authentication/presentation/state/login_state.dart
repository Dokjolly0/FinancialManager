import '../../../../core/errors/app_error.dart';

class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.error,
    this.fieldErrors = const {},
  });

  final bool isSubmitting;
  final AppError? error;
  final Map<String, String> fieldErrors;

  LoginState copyWith({
    bool? isSubmitting,
    AppError? error,
    Map<String, String>? fieldErrors,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
