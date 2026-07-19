import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/auth/access_token_provider.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/media_asset.dart';
import '../../domain/repositories/media_repository.dart';
import '../services/media_api.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl(this._api, this._dio, this._tokenProvider);

  final MediaApi _api;
  final Dio _dio;
  final AccessTokenProvider _tokenProvider;

  @override
  Future<List<MediaAsset>> list({
    required MediaKind kind,
    bool sortRecent = false,
    int limit = 40,
    String? query,
  }) async {
    try {
      final response = await _api.list(
        kind: kind.toApi(),
        sortRecent: sortRecent,
        limit: limit,
        query: query,
      );
      final raw = response['media'] as List<dynamic>? ?? [];
      return raw
          .map((json) => MediaAsset.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<MediaSearchResult>> search({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _api.search(
        query: query,
        page: page,
        limit: limit,
      );
      final raw = response['results'] as List<dynamic>? ?? [];
      return raw
          .map(
            (json) => MediaSearchResult.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<MediaAsset> uploadFile({
    required MediaKind kind,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final response = await _api.uploadFile(
        kind: kind.toApi(),
        bytes: bytes,
        filename: filename,
      );
      return MediaAsset.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<MediaAsset> selectFromSearch({
    required MediaKind kind,
    required String provider,
    required String externalId,
  }) async {
    try {
      final response = await _api.selectFromSearch(
        kind: kind.toApi(),
        provider: provider,
        externalId: externalId,
      );
      return MediaAsset.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _api.delete(id);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<MediaAsset> rename({required String id, required String name}) async {
    try {
      final response = await _api.rename(id: id, name: name);
      return MediaAsset.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  String contentUrl(String id) => '${_dio.options.baseUrl}/media/$id';

  @override
  Map<String, String> authHeaders() {
    final token = _tokenProvider.currentAccessToken;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }
}
