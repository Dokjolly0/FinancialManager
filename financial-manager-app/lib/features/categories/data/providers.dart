import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/models/category.dart';
import '../domain/models/category_sort.dart';
import '../domain/repositories/category_repository.dart';
import 'local/category_sort_store.dart';
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
/// needs to resolve a transaction's category_id to a display name. Hidden
/// categories are included (pickers leave them out). Callers that change
/// a category call `ref.invalidate(categoriesProvider)` to refetch.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).listCategories();
});

final categorySortStoreProvider = Provider<CategorySortStore>(
  (ref) => const SharedPrefsCategorySortStore(),
);

/// The category ordering shared by the picker and the Categories screen:
/// alphabetical until the stored choice has loaded.
final categorySortProvider =
    NotifierProvider<CategorySortNotifier, CategorySort>(
      CategorySortNotifier.new,
    );

class CategorySortNotifier extends Notifier<CategorySort> {
  @override
  CategorySort build() {
    _load();
    return CategorySort.alphabetical;
  }

  Future<void> _load() async {
    final stored = await ref.read(categorySortStoreProvider).read();
    if (stored != null && ref.mounted) state = stored;
  }

  void set(CategorySort sort) {
    state = sort;
    ref.read(categorySortStoreProvider).write(sort);
  }
}
