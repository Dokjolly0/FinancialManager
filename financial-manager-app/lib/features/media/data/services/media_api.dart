import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Thin wrapper over `/v1/media*` (plan.md section 14.8). Returns raw
/// decoded JSON.
class MediaApi {
  MediaApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> list({
    required String kind,
    required bool sortRecent,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/media',
      queryParameters: {
        'kind': kind,
        if (sortRecent) 'sort': 'recent',
        'limit': limit,
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> search({
    required String query,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/media/search',
      queryParameters: {'q': query, 'page': page, 'limit': limit},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> uploadFile({
    required String kind,
    required Uint8List bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'kind': kind,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/media/uploads',
      data: form,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> selectFromSearch({
    required String kind,
    required String provider,
    required String externalId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {'kind': kind, 'provider': provider, 'external_id': externalId},
    );
    return response.data!;
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/media/$id');
  }
}
