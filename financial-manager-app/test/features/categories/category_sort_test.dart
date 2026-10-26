import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/categories/domain/models/category.dart';
import 'package:financialmanager/features/categories/domain/models/category_sort.dart';

Category _category(
  String name, {
  bool isSystem = false,
  int usageCount = 0,
  CategoryDirectionScope scope = CategoryDirectionScope.debit,
}) => Category(
  id: '$name-${scope.name}',
  name: name,
  directionScope: scope,
  isSystem: isSystem,
  sortOrder: 0,
  usageCount: usageCount,
);

List<String> _names(List<Category> categories) =>
    categories.map((c) => c.name).toList();

void main() {
  final categories = [
    _category('Altro', isSystem: true, usageCount: 9),
    _category('zeta', usageCount: 1),
    _category('Casa', isSystem: true, usageCount: 5),
    _category('alimentari', isSystem: true, usageCount: 5),
    _category('Benzina', usageCount: 0),
  ];

  test('alphabetical ignores case and keeps the system "Altro" last', () {
    expect(_names(sortCategories(categories, CategorySort.alphabetical)), [
      'alimentari',
      'Benzina',
      'Casa',
      'zeta',
      'Altro',
    ]);
  });

  test('a custom category named "Altro" is sorted like any other', () {
    final sorted = sortCategories([
      _category('Zucchero'),
      _category('altro'),
    ], CategorySort.alphabetical);
    expect(_names(sorted), ['altro', 'Zucchero']);
  });

  test('most used orders by usage, then alphabetically', () {
    expect(_names(sortCategories(categories, CategorySort.mostUsed)), [
      'Altro',
      'alimentari',
      'Casa',
      'zeta',
      'Benzina',
    ]);
  });

  test('fromKey reads stored names and rejects unknown ones', () {
    expect(CategorySort.fromKey('mostUsed'), CategorySort.mostUsed);
    expect(CategorySort.fromKey('bogus'), isNull);
    expect(CategorySort.fromKey(null), isNull);
  });
}
