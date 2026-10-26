import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/category_sort.dart';

/// The category ordering chosen on this device. Device-local, like the
/// other view conveniences: it isn't account data.
abstract interface class CategorySortStore {
  Future<CategorySort?> read();
  Future<void> write(CategorySort sort);
}

class SharedPrefsCategorySortStore implements CategorySortStore {
  const SharedPrefsCategorySortStore();

  static const _key = 'categories.sort';

  @override
  Future<CategorySort?> read() async => CategorySort.fromKey(
    (await SharedPreferences.getInstance()).getString(_key),
  );

  @override
  Future<void> write(CategorySort sort) async =>
      (await SharedPreferences.getInstance()).setString(_key, sort.name);
}
