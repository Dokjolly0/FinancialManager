class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.generalError,
    this.fieldErrors = const {},
  });

  final bool isSubmitting;
  final String? generalError;
  final Map<String, String> fieldErrors;

  LoginState copyWith({
    bool? isSubmitting,
    String? generalError,
    Map<String, String>? fieldErrors,
  }) {
    return LoginState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: generalError,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
