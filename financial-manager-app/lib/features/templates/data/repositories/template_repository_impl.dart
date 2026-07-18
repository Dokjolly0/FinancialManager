import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../transactions/domain/models/transaction_direction.dart';
import '../../domain/models/transaction_template.dart';
import '../../domain/repositories/template_repository.dart';
import '../services/template_api.dart';

class TemplateRepositoryImpl implements TemplateRepository {
  TemplateRepositoryImpl(this._api);

  final TemplateApi _api;

  @override
  Future<List<TransactionTemplate>> search({
    required TransactionDirection direction,
    String query = '',
    int limit = 8,
  }) async {
    try {
      final response = await _api.search(
        direction: direction.toApi(),
        query: query,
        limit: limit,
      );
      final raw = response['templates'] as List<dynamic>? ?? [];
      return raw
          .map(
            (json) =>
                TransactionTemplate.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<TransactionTemplate> create({
    required TransactionDirection direction,
    required String title,
    String? defaultCategoryId,
    String? defaultDescription,
  }) async {
    try {
      final response = await _api.create({
        'direction': direction.toApi(),
        'title': title,
        'default_category_id': defaultCategoryId,
        'default_description': defaultDescription,
      });
      return TransactionTemplate.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<TransactionTemplate> update(
    String id, {
    required String title,
    String? defaultCategoryId,
    String? defaultDescription,
  }) async {
    try {
      final response = await _api.update(id, {
        'title': title,
        'default_category_id': defaultCategoryId,
        'default_description': defaultDescription,
      });
      return TransactionTemplate.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
