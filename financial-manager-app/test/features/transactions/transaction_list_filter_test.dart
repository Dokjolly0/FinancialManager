import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/transactions/domain/repositories/transaction_repository.dart';

void main() {
  group('TransactionListFilter.activeCount', () {
    test('is zero for the default (unfiltered) filter', () {
      expect(const TransactionListFilter().activeCount, 0);
    });

    test('counts every non-default field', () {
      final filter = TransactionListFilter(
        type: TransactionTypeFilter.debit,
        walletId: 'wallet-1',
        title: 'caffè',
        categoryId: 'cat-1',
        amountMinMinor: 100,
        amountMaxMinor: 5000,
        occurredFrom: DateTime(2026, 1, 1),
        occurredTo: DateTime(2026, 2, 1),
      );
      expect(filter.activeCount, 8);
    });

    test('paymentGroupId is not a user-facing filter and never counts', () {
      // paymentGroupId only exists for the transaction detail screen's
      // "pagamenti collegati" section to fetch a group's members — it must
      // never surface as an active filter in Cronologia's filter badge.
      const filter = TransactionListFilter(paymentGroupId: 'group-1');
      expect(filter.activeCount, 0);
    });
  });

  group('TransactionListFilter.copyWith', () {
    test('clearX flags reset a field to null instead of keeping it', () {
      const original = TransactionListFilter(
        title: 'caffè',
        categoryId: 'cat-1',
        amountMinMinor: 100,
      );

      final cleared = original.copyWith(
        clearTitle: true,
        clearCategoryId: true,
        clearAmountMinMinor: true,
      );

      expect(cleared.title, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared.amountMinMinor, isNull);
    });

    test('clearWalletId resets the wallet filter to null', () {
      const original = TransactionListFilter(walletId: 'wallet-1');

      final cleared = original.copyWith(clearWalletId: true);

      expect(cleared.walletId, isNull);
    });

    test('omitting a field leaves its previous value untouched', () {
      const original = TransactionListFilter(title: 'caffè');
      final updated = original.copyWith(categoryId: 'cat-2');

      expect(updated.title, 'caffè');
      expect(updated.categoryId, 'cat-2');
    });
  });
}
