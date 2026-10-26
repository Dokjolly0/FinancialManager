import '../models/category.dart';

/// Domain-facing category operations (plan.md section 14.7). Only the
/// user's own categories can be updated or deleted; system ones can only
/// be hidden.
abstract class CategoryRepository {
  Future<List<Category>> listCategories();

  Future<Category> createCategory({
    required String name,
    required CategoryDirectionScope directionScope,
    String? color,
  });

  Future<Category> updateCategory({
    required String id,
    required String name,
    required CategoryDirectionScope directionScope,
    String? color,
  });

  /// Archives the category; the backend leaves its transactions and
  /// templates without a category.
  Future<void> deleteCategory(String id);

  Future<void> setCategoryHidden(String id, {required bool hidden});
}
