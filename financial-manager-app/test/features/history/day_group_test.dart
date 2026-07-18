import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/history/domain/day_group.dart';
import 'package:financialmanager/features/transactions/domain/models/ledger_transaction.dart';
import 'package:financialmanager/features/transactions/domain/models/transaction_direction.dart';
import 'package:financialmanager/core/formatting/money.dart';

LedgerTransaction _tx({
  required String id,
  required TransactionDirection direction,
  required int amountMinor,
  required DateTime occurredAt,
}) {
  return LedgerTransaction(
    id: id,
    direction: direction,
    kind: TransactionKind.standard,
    amount: Money(minorUnits: amountMinor, currency: 'EUR'),
    title: 'Test $id',
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    version: 1,
  );
}

void main() {
  test('groups transactions by local calendar day, newest day first', () {
    final transactions = [
      _tx(
        id: '1',
        direction: TransactionDirection.debit,
        amountMinor: 1000,
        occurredAt: DateTime.utc(2026, 7, 18, 10),
      ),
      _tx(
        id: '2',
        direction: TransactionDirection.credit,
        amountMinor: 500,
        occurredAt: DateTime.utc(2026, 7, 18, 12),
      ),
      _tx(
        id: '3',
        direction: TransactionDirection.debit,
        amountMinor: 2000,
        occurredAt: DateTime.utc(2026, 7, 17, 9),
      ),
    ];

    final groups = DayGroup.group(transactions);

    expect(groups.length, 2);
    expect(groups.first.transactions.map((t) => t.id), ['1', '2']);
    expect(groups.last.transactions.map((t) => t.id), ['3']);
  });

  test('computes the net total per day (credits minus debits)', () {
    final day = DateTime.utc(2026, 7, 18, 10);
    final transactions = [
      _tx(
        id: '1',
        direction: TransactionDirection.debit,
        amountMinor: 1000,
        occurredAt: day,
      ),
      _tx(
        id: '2',
        direction: TransactionDirection.credit,
        amountMinor: 1500,
        occurredAt: day,
      ),
    ];

    final groups = DayGroup.group(transactions);

    expect(groups.single.netMinor, 500);
  });
}
