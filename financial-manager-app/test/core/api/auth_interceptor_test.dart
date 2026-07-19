import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/api/auth_interceptor.dart';
import 'package:financialmanager/core/auth/access_token_provider.dart';

/// Records the byte length of every request body the adapter receives,
/// returning 401 on the first call and 200 on every call after — enough to
/// exercise AuthInterceptor's refresh-and-retry-once path without a real
/// server.
class _FakeAdapter implements HttpClientAdapter {
  int callCount = 0;
  final List<int> bodyLengths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    var length = 0;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        length += chunk.length;
      }
    }
    bodyLengths.add(length);

    if (callCount == 1) {
      return ResponseBody.fromString(
        '{"error":"unauthorized"}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeTokenProvider implements AccessTokenProvider {
  String token = 'stale-token';
  bool sessionExpired = false;

  @override
  String? get currentAccessToken => token;

  @override
  Future<String?> refreshAccessToken() async {
    token = 'fresh-token';
    return token;
  }

  @override
  Future<void> onSessionExpired() async {
    sessionExpired = true;
  }
}

void main() {
  test(
    'retries a multipart upload with a fresh (non-empty) body after a 401 refresh',
    () async {
      final adapter = _FakeAdapter();
      final tokenProvider = _FakeTokenProvider();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(tokenProvider, dio));

      final form = FormData.fromMap({
        'kind': 'transaction',
        'file': MultipartFile.fromBytes(
          List<int>.filled(1000, 1),
          filename: 'photo.jpg',
        ),
      });

      final response = await dio.post<String>('/media/uploads', data: form);

      expect(adapter.callCount, 2, reason: 'should retry exactly once');
      expect(response.statusCode, 200);
      expect(
        adapter.bodyLengths[0],
        greaterThan(0),
        reason: 'the original request must carry the file bytes',
      );
      expect(
        adapter.bodyLengths[1],
        adapter.bodyLengths[0],
        reason:
            'the retried request must resend the full body, not an '
            'exhausted/empty multipart stream',
      );
      expect(tokenProvider.sessionExpired, isFalse);
    },
  );
}
