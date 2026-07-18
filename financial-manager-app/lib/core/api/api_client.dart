import 'package:dio/dio.dart';

import '../auth/access_token_provider.dart';
import '../observability/app_logger.dart';
import 'api_environment.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'request_id_interceptor.dart';

/// Builds the shared [Dio] instance used by every feature repository.
/// Cross-cutting concerns (correlation ID, auth, logging, timeouts) are
/// wired here once (plan.md section 9.5) instead of per-feature.
///
/// Retries are deliberately not implemented at this layer: per the plan,
/// retrying is only safe for idempotent requests or ones carrying an
/// Idempotency-Key, which is a per-endpoint decision made by the calling
/// repository, not a blanket policy here.
class ApiClient {
  ApiClient({
    required ApiEnvironment environment,
    required AccessTokenProvider tokenProvider,
    AppLogger? logger,
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: environment.resolveBaseUrl(),
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
         ),
       ) {
    _dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(tokenProvider, _dio),
      LoggingInterceptor(logger ?? const DeveloperLogger()),
    ]);
  }

  final Dio _dio;

  /// The underlying Dio instance, for repositories that need direct access
  /// (e.g. multipart upload with progress callbacks).
  Dio get dio => _dio;

  /// Cancels all in-flight requests tagged with [cancelToken]. Screens
  /// should create one [CancelToken] per lifecycle and cancel it on
  /// dispose (plan.md section 9.5: "cancellazione richieste quando una
  /// schermata viene chiusa").
  void cancel(CancelToken cancelToken, [String? reason]) {
    if (!cancelToken.isCancelled) {
      cancelToken.cancel(reason);
    }
  }
}
