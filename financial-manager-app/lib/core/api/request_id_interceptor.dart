import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Attaches a correlation ID to every outgoing request so it can be traced
/// end-to-end through the backend's own request ID propagation (plan.md
/// section 22.2: "Flutter → API → handler → service → repository").
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  static const headerName = 'X-Request-Id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[headerName] = _uuid.v4();
    handler.next(options);
  }
}
