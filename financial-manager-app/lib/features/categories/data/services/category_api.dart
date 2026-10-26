import 'package:dio/dio.dart';

/// Thin wrapper over `/v1/categories` (plan.md section 14.7). Returns raw
/// decoded JSON.
class CategoryApi {
  CategoryApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/categories');
    return response.data!;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/categories',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/categories/$id',
      data: body,
    );
    return response.data!;
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/categories/$id');
  }

  Future<void> setHidden(String id, {required bool hidden}) async {
    if (hidden) {
      await _dio.put<void>('/categories/$id/hidden');
    } else {
      await _dio.delete<void>('/categories/$id/hidden');
    }
  }
}
