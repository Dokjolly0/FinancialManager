import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/transactions/domain/models/ledger_transaction.dart';

Map<String, dynamic> _baseJson({String? paymentGroupId}) => {
  'id': 'tx-1',
  'wallet_id': 'wallet-1',
  'direction': 'DEBIT',
  'kind': 'STANDARD',
  'amount_minor': 10000,
  'currency': 'EUR',
  'title': 'Acconto viaggio',
  'occurred_at': '2026-01-01T10:00:00Z',
  'created_at': '2026-01-01T10:00:00Z',
  'updated_at': '2026-01-01T10:00:00Z',
  'version': 1,
  'payment_group_id': ?paymentGroupId,
};

void main() {
  group('LedgerTransaction.fromJson payment_group_id', () {
    test('parses a present payment_group_id', () {
      final transaction = LedgerTransaction.fromJson(
        _baseJson(paymentGroupId: 'group-1'),
      );
      expect(transaction.paymentGroupId, 'group-1');
    });

    test('is null when the field is absent (standalone transaction)', () {
      final transaction = LedgerTransaction.fromJson(_baseJson());
      expect(transaction.paymentGroupId, isNull);
    });
  });

  group('LedgerTransaction.isEditable', () {
    test('stays true for a plain standard transaction with a payment group', () {
      // Being linked to other payments doesn't change how a plain
      // transaction is edited/deleted — the link is purely a display
      // grouping, unlike linkedTransactionId's accounting-driven pairing.
      final transaction = LedgerTransaction.fromJson(
        _baseJson(paymentGroupId: 'group-1'),
      );
      expect(transaction.isEditable, isTrue);
    });
  });
}
