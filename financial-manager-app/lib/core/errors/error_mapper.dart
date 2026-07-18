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

    if (status == 401) {
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
