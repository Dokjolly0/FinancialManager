/// Domain-level error types the UI reacts to. These are produced from raw
/// transport errors (Dio exceptions, the backend's JSON error envelope) by
/// [ErrorMapper] so screens never need to know about HTTP status codes or
/// Dio directly (plan.md section 9.5: "mapping errori API → errori di
/// dominio").
sealed class AppError {
  const AppError({this.requestId});

  /// Correlation ID from the backend response, if any, useful for support.
  final String? requestId;
}

/// No network connectivity or the request timed out before reaching the server.
final class NetworkError extends AppError {
  const NetworkError({super.requestId});
}

/// The access token is invalid/expired and refresh also failed; the user
/// must sign in again (plan.md section 15.6).
final class SessionExpiredError extends AppError {
  const SessionExpiredError({super.requestId});
}

/// The server rejected the request for a domain reason (HTTP 400/422/409),
/// carrying a machine-readable [code] and optional per-field messages.
final class DomainError extends AppError {
  const DomainError({
    required this.code,
    required this.message,
    this.fieldErrors = const {},
    super.requestId,
  });

  final String code;
  final String message;
  final Map<String, String> fieldErrors;
}

/// The caller was rate-limited (HTTP 429).
final class RateLimitedError extends AppError {
  const RateLimitedError({this.retryAfter, super.requestId});

  final Duration? retryAfter;
}

/// Anything else: unexpected 5xx, malformed response, or an exception with
/// no more specific mapping.
final class UnknownError extends AppError {
  const UnknownError({this.cause, super.requestId});

  final Object? cause;
}
