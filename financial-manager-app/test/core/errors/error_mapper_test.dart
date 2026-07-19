import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/errors/app_error.dart';
import 'package:financialmanager/core/errors/error_mapper.dart';

RequestOptions _requestOptions() => RequestOptions(path: '/v1/transactions');

void main() {
  group('ErrorMapper', () {
    test('maps connection timeout to NetworkError', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.connectionTimeout,
      );

      expect(ErrorMapper.fromException(error), isA<NetworkError>());
    });

    test('maps a bodyless 401 to SessionExpiredError', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: _requestOptions(), statusCode: 401),
      );

      expect(ErrorMapper.fromException(error), isA<SessionExpiredError>());
    });

    test('maps a 401 with code UNAUTHORIZED to SessionExpiredError', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 401,
          data: {
            'error': {
              'code': 'UNAUTHORIZED',
              'message': 'Authentication required or invalid.',
            },
          },
        ),
      );

      expect(ErrorMapper.fromException(error), isA<SessionExpiredError>());
    });

    test(
      'maps a 401 with a domain code (e.g. wrong current password) to DomainError, not SessionExpiredError',
      () {
        final error = DioException(
          requestOptions: _requestOptions(),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: _requestOptions(),
            statusCode: 401,
            data: {
              'error': {
                'code': 'INVALID_CURRENT_PASSWORD',
                'message': 'The current password is incorrect.',
              },
            },
          ),
        );

        final mapped = ErrorMapper.fromException(error) as DomainError;
        expect(mapped.code, 'INVALID_CURRENT_PASSWORD');
        expect(mapped.message, 'The current password is incorrect.');
      },
    );

    test('maps 429 to RateLimitedError with retry-after', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );

      final mapped = ErrorMapper.fromException(error) as RateLimitedError;
      expect(mapped.retryAfter, const Duration(seconds: 30));
    });

    test('maps a 422 error envelope to DomainError with field errors', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: _requestOptions(),
          statusCode: 422,
          data: {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'The request contains invalid data.',
              'field_errors': {'amount_minor': 'AMOUNT_NOT_POSITIVE'},
              'request_id': 'req-123',
            },
          },
        ),
      );

      final mapped = ErrorMapper.fromException(error) as DomainError;
      expect(mapped.code, 'VALIDATION_ERROR');
      expect(mapped.fieldErrors['amount_minor'], 'AMOUNT_NOT_POSITIVE');
      expect(mapped.requestId, 'req-123');
    });

    test('falls back to UnknownError for a non-Dio exception', () {
      expect(ErrorMapper.fromException(Exception('boom')), isA<UnknownError>());
    });
  });
}
