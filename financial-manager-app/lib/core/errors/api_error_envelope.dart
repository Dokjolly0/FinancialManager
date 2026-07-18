/// Mirrors the backend's uniform error response (plan.md section 10.6):
///
/// ```json
/// {
///   "error": {
///     "code": "TRANSACTION_VERSION_CONFLICT",
///     "message": "...",
///     "field_errors": { "amount_minor": "Deve essere maggiore di zero" },
///     "request_id": "..."
///   }
/// }
/// ```
class ApiErrorEnvelope {
  const ApiErrorEnvelope({
    required this.code,
    required this.message,
    this.fieldErrors = const {},
    this.requestId,
  });

  final String code;
  final String message;
  final Map<String, String> fieldErrors;
  final String? requestId;

  static ApiErrorEnvelope? tryParse(Object? json) {
    if (json is! Map) return null;
    final error = json['error'];
    if (error is! Map) return null;

    final code = error['code'];
    final message = error['message'];
    if (code is! String || message is! String) return null;

    final rawFieldErrors = error['field_errors'];
    final fieldErrors = <String, String>{};
    if (rawFieldErrors is Map) {
      for (final entry in rawFieldErrors.entries) {
        if (entry.key is String && entry.value is String) {
          fieldErrors[entry.key as String] = entry.value as String;
        }
      }
    }

    return ApiErrorEnvelope(
      code: code,
      message: message,
      fieldErrors: fieldErrors,
      requestId: error['request_id'] as String?,
    );
  }
}
