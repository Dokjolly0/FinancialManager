import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/categories/domain/models/category.dart';
import 'package:financialmanager/features/transactions/domain/models/transaction_direction.dart';

Category _category(CategoryDirectionScope scope) => Category(
  id: 'c1',
  name: 'Test',
  directionScope: scope,
  isSystem: false,
  sortOrder: 0,
);

void main() {
  group('Category.matches', () {
    test('a DEBIT category only matches debit operations', () {
      final category = _category(CategoryDirectionScope.debit);
      expect(category.matches(TransactionDirection.debit), isTrue);
      expect(category.matches(TransactionDirection.credit), isFalse);
    });

    test('a CREDIT category only matches credit operations', () {
      final category = _category(CategoryDirectionScope.credit);
      expect(category.matches(TransactionDirection.credit), isTrue);
      expect(category.matches(TransactionDirection.debit), isFalse);
    });

    test('a BOTH category matches either direction', () {
      final category = _category(CategoryDirectionScope.both);
      expect(category.matches(TransactionDirection.debit), isTrue);
      expect(category.matches(TransactionDirection.credit), isTrue);
    });
  });

  test('fromJson parses the backend shape', () {
    final category = Category.fromJson({
      'id': 'abc',
      'name': 'Alimentari',
      'direction_scope': 'DEBIT',
      'is_system': true,
      'sort_order': 1,
    });
    expect(category.id, 'abc');
    expect(category.name, 'Alimentari');
    expect(category.directionScope, CategoryDirectionScope.debit);
    expect(category.isSystem, isTrue);
  });
}
