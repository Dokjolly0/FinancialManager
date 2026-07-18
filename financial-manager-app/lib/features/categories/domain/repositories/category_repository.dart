import '../models/category.dart';

/// Domain-facing category operations (plan.md section 14.7). Update/delete
/// of custom categories isn't exposed to the client yet — no screen needs
/// it before an account-settings "manage categories" screen exists.
abstract class CategoryRepository {
  Future<List<Category>> listCategories();

  Future<Category> createCategory({
    required String name,
    required CategoryDirectionScope directionScope,
    String? color,
  });
}
