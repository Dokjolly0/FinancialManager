import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/models/category.dart';
import '../domain/repositories/category_repository.dart';
import 'repositories/category_repository_impl.dart';
import 'services/category_api.dart';

final categoryApiProvider = Provider<CategoryApi>((ref) {
  return CategoryApi(ref.watch(apiClientProvider).dio);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoryApiProvider));
});

/// Cached list of every category visible to the user (system + own),
/// shared by the category picker, the history filters, and any screen that
/// needs to resolve a transaction's category_id to a display name. Callers
/// that just created a category call `ref.invalidate(categoriesProvider)`
/// to refetch.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).listCategories();
});
