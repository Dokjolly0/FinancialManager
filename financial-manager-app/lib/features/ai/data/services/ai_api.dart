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

  Future<void> acceptConsent(int version) =>
      _dio.put<void>('/ai/consent', data: {'consent_version': version});

  Future<void> revokeConsent() => _dio.delete<void>('/ai/consent');

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

  Future<Map<String, dynamic>> listAnalyses({
    String? cursor,
    int limit = 20,
  }) async => (await _dio.get<Map<String, dynamic>>(
    '/ai/analyses',
    queryParameters: {'limit': limit, 'cursor': ?cursor},
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
