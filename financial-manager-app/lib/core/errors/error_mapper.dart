import 'package:dio/dio.dart';

import 'api_error_envelope.dart';
import 'app_error.dart';

/// Converts transport-level failures (Dio exceptions) into [AppError]s the
/// UI can render without knowing about HTTP or Dio.
abstract final class ErrorMapper {
  static AppError fromException(Object error) {
    if (error is! DioException) {
      return UnknownError(cause: error);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkError();
      case DioExceptionType.cancel:
        return UnknownError(cause: error);
      case DioExceptionType.badCertificate:
        return UnknownError(cause: error);
      case DioExceptionType.badResponse:
        return _fromResponse(error);
      case DioExceptionType.unknown:
        return const NetworkError();
    }
  }

  static AppError _fromResponse(DioException error) {
    final response = error.response;
    final status = response?.statusCode ?? 0;
    final envelope = ApiErrorEnvelope.tryParse(response?.data);

    // 401 is not exclusively "the access token is invalid/expired" — some
    // endpoints reuse it for a rejected domain-level credential (e.g.
    // wrong current password on change-password/delete-account, wrong
    // password on login), each with their own envelope code. Only the
    // backend's generic UNAUTHORIZED code (or a 401 with no parseable
    // envelope at all, e.g. a missing/malformed token) means the session
    // itself is the problem; anything else with a body is a domain error
    // and must keep its own message/field_errors instead of being
    // overwritten with "Sessione scaduta" (found live: a wrong current
    // password on the change-password screen was showing that message).
    if (status == 401 &&
        (envelope == null || envelope.code == 'UNAUTHORIZED')) {
      return SessionExpiredError(requestId: envelope?.requestId);
    }

    if (status == 429) {
      final retryAfterHeader = response?.headers.value('retry-after');
      final retryAfterSeconds = int.tryParse(retryAfterHeader ?? '');
      return RateLimitedError(
        retryAfter: retryAfterSeconds != null
            ? Duration(seconds: retryAfterSeconds)
            : null,
        requestId: envelope?.requestId,
      );
    }

    if (envelope != null) {
      return DomainError(
        code: envelope.code,
        message: envelope.message,
        fieldErrors: envelope.fieldErrors,
        requestId: envelope.requestId,
      );
    }

    return UnknownError(cause: error);
  }
}
