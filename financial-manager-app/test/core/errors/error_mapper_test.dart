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
              'message': 'Autenticazione richiesta o non valida.',
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
                'message': 'La password attuale non è corretta.',
              },
            },
          ),
        );

        final mapped = ErrorMapper.fromException(error) as DomainError;
        expect(mapped.code, 'INVALID_CURRENT_PASSWORD');
        expect(mapped.message, 'La password attuale non è corretta.');
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
              'message': 'Richiesta non valida',
              'field_errors': {'amount_minor': 'Deve essere maggiore di zero'},
              'request_id': 'req-123',
            },
          },
        ),
      );

      final mapped = ErrorMapper.fromException(error) as DomainError;
      expect(mapped.code, 'VALIDATION_ERROR');
      expect(
        mapped.fieldErrors['amount_minor'],
        'Deve essere maggiore di zero',
      );
      expect(mapped.requestId, 'req-123');
    });

    test('falls back to UnknownError for a non-Dio exception', () {
      expect(ErrorMapper.fromException(Exception('boom')), isA<UnknownError>());
    });
  });
}
