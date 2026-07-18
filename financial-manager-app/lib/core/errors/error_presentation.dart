import 'app_error.dart';

/// A user-facing rendering of an [AppError]: a message plus any per-field
/// messages a form should show inline (plan.md section 10.6 field_errors).
class ErrorPresentation {
  const ErrorPresentation({required this.message, this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;
}

/// Maps a transport-level [AppError] to text a screen can show directly,
/// without every view-model re-implementing this switch.
ErrorPresentation presentError(AppError error) {
  return switch (error) {
    NetworkError() => const ErrorPresentation(
      message: 'Connessione assente. Controlla la rete e riprova.',
    ),
    SessionExpiredError() => const ErrorPresentation(
      message: 'Sessione scaduta. Accedi di nuovo.',
    ),
    RateLimitedError(:final retryAfter) => ErrorPresentation(
      message: retryAfter == null
          ? 'Troppi tentativi. Riprova più tardi.'
          : 'Troppi tentativi. Riprova tra ${retryAfter.inSeconds} secondi.',
    ),
    DomainError(:final message, :final fieldErrors) => ErrorPresentation(
      message: message,
      fieldErrors: fieldErrors,
    ),
    UnknownError() => const ErrorPresentation(
      message: 'Si è verificato un errore imprevisto. Riprova.',
    ),
  };
}
