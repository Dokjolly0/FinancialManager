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
    DomainError(:final code, :final fieldErrors) => ErrorPresentation(
      message: localizeErrorCode(l10n, code),
      fieldErrors: fieldErrors.map(
        (field, fieldCode) => MapEntry(field, localizeErrorCode(l10n, fieldCode)),
      ),
    ),
    UnknownError() => ErrorPresentation(message: l10n.errorCodeUnknownError),
  };
}
