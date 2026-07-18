import 'package:dio/dio.dart';

import '../auth/access_token_provider.dart';

/// Attaches the access token to every request and, on a 401, refreshes it
/// once and retries the original request. Concurrent 401s share a single
/// in-flight refresh instead of each triggering their own (plan.md section
/// 9.5: "refresh token serializzato, evitando richieste refresh concorrenti").
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider, this._dio);

  final AccessTokenProvider _tokenProvider;
  final Dio _dio;

  Future<String?>? _inFlightRefresh;

  static const _retriedKey = 'auth_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.currentAccessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    final newToken = await (_inFlightRefresh ??= _refresh());
    if (newToken == null) {
      await _tokenProvider.onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra[_retriedKey] = true;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      final retryResponse = await _dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<String?> _refresh() async {
    try {
      return await _tokenProvider.refreshAccessToken();
    } finally {
      _inFlightRefresh = null;
    }
  }
}
