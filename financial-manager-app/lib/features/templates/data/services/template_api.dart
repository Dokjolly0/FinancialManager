import 'package:dio/dio.dart';

/// Thin wrapper over `/v1/transaction-templates` (plan.md section 14.6).
/// Returns raw decoded JSON.
class TemplateApi {
  TemplateApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> search({
    required String direction,
    required String query,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transaction-templates',
      queryParameters: {
        'direction': direction,
        if (query.isNotEmpty) 'q': query,
        'limit': limit,
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/transaction-templates',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/transaction-templates/$id',
      data: body,
    );
    return response.data!;
  }
}
