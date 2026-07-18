import 'package:dio/dio.dart';

import '../observability/app_logger.dart';
import 'request_id_interceptor.dart';

/// Logs one line per response/error: method, path, status, latency,
/// correlation ID. Never logs request/response bodies — they may contain
/// transaction descriptions, tokens, or other data that must not be logged
/// (plan.md section 19.7).
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._logger);

  final AppLogger _logger;

  static const _startTimeKey = 'request_start_time';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, status: response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, status: err.response?.statusCode);
    handler.next(err);
  }

  void _log(RequestOptions options, {int? status}) {
    final start = options.extra[_startTimeKey] as DateTime?;
    final durationMs = start == null
        ? null
        : DateTime.now().difference(start).inMilliseconds;

    _logger.info(
      'http_request',
      context: {
        'method': options.method,
        'path': options.path,
        'status': status,
        'duration_ms': durationMs,
        'request_id': options.headers[RequestIdInterceptor.headerName],
      },
    );
  }
}
