import 'package:dio/dio.dart';

import '../../../../core/api/sse.dart';

/// Thin wrapper over `/v1/ai/*` (plan.md section 32.4). Returns raw
/// decoded JSON or raw events; the repository maps them to domain models.
class AiApi {
  AiApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getSettings() async =>
      (await _dio.get<Map<String, dynamic>>('/ai/settings')).data!;

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> body) async =>
      (await _dio.put<Map<String, dynamic>>('/ai/settings', data: body)).data!;

  Future<void> deleteCredential(String id) =>
      _dio.delete<void>('/ai/credentials/$id');

  Future<Map<String, dynamic>> testConnection(
    Map<String, dynamic> body,
  ) async => (await _dio.post<Map<String, dynamic>>(
    '/ai/settings/test',
    data: body,
    // The probe calls the provider: allow a slow first response.
    options: Options(receiveTimeout: const Duration(seconds: 45)),
  )).data!;

  Future<List<dynamic>> listModels(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/models',
      data: body,
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return response.data!['models'] as List<dynamic>? ?? [];
  }

  Future<void> acceptConsent(int version, String scope) => _dio.put<void>(
    '/ai/consent',
    data: {'consent_version': version, 'scope': scope},
  );

  Future<void> revokeConsent(String scope) =>
      _dio.delete<void>('/ai/consent', queryParameters: {'scope': scope});

  Future<Map<String, dynamic>> setMode(Map<String, dynamic> body) async =>
      (await _dio.put<Map<String, dynamic>>('/ai/mode', data: body)).data!;

  Future<Map<String, dynamic>> prepareLocalAnalysis(
    Map<String, dynamic> body,
  ) async => (await _dio.post<Map<String, dynamic>>(
    '/ai/local/analyses',
    data: body,
  )).data!;

  Future<Map<String, dynamic>> prepareLocalFollowUp(
    String id,
    String question,
  ) async => (await _dio.post<Map<String, dynamic>>(
    '/ai/local/analyses/$id/messages',
    data: {'content': question},
  )).data!;

  Future<Map<String, dynamic>> submitLocalResult(
    String analysisId,
    String messageId,
    Map<String, dynamic> body,
  ) async => (await _dio.put<Map<String, dynamic>>(
    '/ai/analyses/$analysisId/messages/$messageId/result',
    data: body,
  )).data!;

  Future<Map<String, dynamic>> getUserContext() async =>
      (await _dio.get<Map<String, dynamic>>('/ai/context')).data!;

  Future<Map<String, dynamic>> saveUserContext(
    Map<String, dynamic> body,
  ) async =>
      (await _dio.put<Map<String, dynamic>>('/ai/context', data: body)).data!;

  Future<List<dynamic>> listPresets() async {
    final response = await _dio.get<Map<String, dynamic>>('/ai/presets');
    return response.data!['presets'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> preview(Map<String, dynamic> body) async =>
      (await _dio.post<Map<String, dynamic>>(
        '/ai/analyses/preview',
        data: body,
      )).data!;

  Stream<SseEvent> runAnalysis(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) => postSse(_dio, '/ai/analyses', body, cancelToken: cancelToken);

  Stream<SseEvent> askFollowUp(
    String id,
    String question, {
    CancelToken? cancelToken,
  }) => postSse(_dio, '/ai/analyses/$id/messages', {
    'content': question,
  }, cancelToken: cancelToken);

  /// [type] is 'chat', 'report' or null for both.
  Future<Map<String, dynamic>> listAnalyses({
    String? cursor,
    int limit = 20,
    String? type,
  }) async => (await _dio.get<Map<String, dynamic>>(
    '/ai/analyses',
    queryParameters: {'limit': limit, 'cursor': ?cursor, 'type': ?type},
  )).data!;

  Future<Map<String, dynamic>> getAnalysis(String id) async =>
      (await _dio.get<Map<String, dynamic>>('/ai/analyses/$id')).data!;

  Future<Map<String, dynamic>> renameAnalysis(String id, String title) async =>
      (await _dio.patch<Map<String, dynamic>>(
        '/ai/analyses/$id',
        data: {'title': title},
      )).data!;

  Future<void> deleteAnalysis(String id) =>
      _dio.delete<void>('/ai/analyses/$id');

  Future<void> deleteAllAnalyses() => _dio.delete<void>('/ai/analyses');
}
