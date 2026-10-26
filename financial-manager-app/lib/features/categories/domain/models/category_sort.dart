import 'category.dart';

/// How category lists are ordered (plan.md section 7.6): alphabetically by
/// default, or most used first. Chosen with the toggle in the picker and
/// the Categories screen, and remembered on the device.
enum CategorySort {
  alphabetical,
  mostUsed;

  static CategorySort? fromKey(String? key) =>
      CategorySort.values.where((s) => s.name == key).firstOrNull;
}

/// Returns [categories] in [sort] order. Alphabetical is case-insensitive,
/// with the system "Altro" (the catch-all) always last; most used orders
/// by usage count, then alphabetically.
List<Category> sortCategories(
  Iterable<Category> categories,
  CategorySort sort,
) {
  int alphabetical(Category a, Category b) {
    final catchAll = (_isCatchAll(a) ? 1 : 0) - (_isCatchAll(b) ? 1 : 0);
    if (catchAll != 0) return catchAll;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (byName != 0) return byName;
    return a.directionScope.index - b.directionScope.index;
  }

  return categories.toList()..sort(
    (a, b) => switch (sort) {
      CategorySort.alphabetical => alphabetical(a, b),
      CategorySort.mostUsed =>
        b.usageCount != a.usageCount
            ? b.usageCount - a.usageCount
            : alphabetical(a, b),
    },
  );
}

bool _isCatchAll(Category c) => c.isSystem && c.name.toLowerCase() == 'altro';
