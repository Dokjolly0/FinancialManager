import '../../l10n/app_localizations.dart';
import 'app_error.dart';
import 'error_code_localizations.dart';

/// A user-facing rendering of an [AppError]: a message plus any per-field
/// messages a form should show inline (plan.md section 10.6 field_errors).
class ErrorPresentation {
  const ErrorPresentation({required this.message, this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;
}

/// Maps a transport-level [AppError] to text a screen can show directly,
/// without every view-model re-implementing this switch. Resolves through
/// [l10n] rather than any server-supplied text, so the result is always in
/// the user's selected language (plan.md section 9.5).
ErrorPresentation presentError(AppError error, AppLocalizations l10n) {
  return switch (error) {
    NetworkError() => ErrorPresentation(message: l10n.errorCodeNetworkError),
    SessionExpiredError() => ErrorPresentation(
      message: l10n.errorCodeSessionExpired,
    ),
    RateLimitedError(:final retryAfter) => ErrorPresentation(
      message: retryAfter == null
          ? l10n.errorCodeRateLimitedGeneric
          : l10n.errorCodeRateLimitedWithSeconds(retryAfter.inSeconds),
    ),
    DomainError(:final code, :final fieldErrors) => _presentDomain(
      l10n,
      code,
      fieldErrors,
    ),
    UnknownError() => ErrorPresentation(message: l10n.errorCodeUnknownError),
  };
}

ErrorPresentation _presentDomain(
  AppLocalizations l10n,
  String code,
  Map<String, String> fieldErrors,
) {
  final error = DomainError(code: code, message: '', fieldErrors: fieldErrors);
  return ErrorPresentation(
    message: localizeErrorCode(l10n, code),
    fieldErrors: fieldErrors.map(
      (field, fieldCode) =>
          MapEntry(field, localizeFieldError(l10n, fieldCode, error)),
    ),
  );
}

/// Text for one field error a form holds (a client-side validation code or
/// one from the server's field_errors). A code the app has no text for (an
/// older or newer backend, or a server message instead of a code) falls
/// back to the text of [error]'s own code, e.g. "Username già in uso",
/// rather than "Si è verificato un errore imprevisto".
String localizeFieldError(
  AppLocalizations l10n,
  String fieldCode,
  AppError? error,
) {
  final text = localizeErrorCode(l10n, fieldCode);
  if (text == l10n.errorCodeUnknownError && error is DomainError) {
    return localizeErrorCode(l10n, error.code);
  }
  return text;
}
