import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../services/category_api.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._api);

  final CategoryApi _api;

  @override
  Future<List<Category>> listCategories() async {
    try {
      final response = await _api.list();
      final raw = response['categories'] as List<dynamic>? ?? [];
      return raw
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Category> createCategory({
    required String name,
    required CategoryDirectionScope directionScope,
    String? color,
  }) async {
    try {
      final response = await _api.create({
        'name': name,
        'direction_scope': directionScope.toApi(),
        'color': color,
      });
      return Category.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Category> updateCategory({
    required String id,
    required String name,
    required CategoryDirectionScope directionScope,
    String? color,
  }) async {
    try {
      final response = await _api.update(id, {
        'name': name,
        'direction_scope': directionScope.toApi(),
        'color': color,
      });
      return Category.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _api.delete(id);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> setCategoryHidden(String id, {required bool hidden}) async {
    try {
      await _api.setHidden(id, hidden: hidden);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
