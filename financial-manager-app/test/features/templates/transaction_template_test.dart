import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/templates/domain/models/transaction_template.dart';

void main() {
  group('normalizeTemplateTitle', () {
    test('trims and compacts internal whitespace', () {
      expect(normalizeTemplateTitle('  Bar   Centrale  '), 'bar centrale');
    });

    test('is case-insensitive', () {
      expect(normalizeTemplateTitle('CAFFÈ'), normalizeTemplateTitle('caffè'));
    });
  });

  test('fromJson parses the backend shape', () {
    final template = TransactionTemplate.fromJson({
      'id': 't1',
      'direction': 'DEBIT',
      'title': 'Bar Centrale',
      'usage_count': 3,
    });
    expect(template.id, 't1');
    expect(template.title, 'Bar Centrale');
    expect(template.usageCount, 3);
    expect(template.defaultCategoryId, isNull);
  });
}
