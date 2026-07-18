import '../../transactions/domain/models/ledger_transaction.dart';
import '../../transactions/domain/models/transaction_direction.dart';

/// One day's worth of transactions for the grouped Cronologia list
/// (plan.md section 7.9: "Raggruppata per giorno. Totale netto del giorno
/// facoltativo."). Transactions are assumed already sorted newest-first,
/// same order the backend returns.
class DayGroup {
  const DayGroup({
    required this.day,
    required this.transactions,
    required this.netMinor,
  });

  final DateTime day;
  final List<LedgerTransaction> transactions;
  final int netMinor;

  static List<DayGroup> group(List<LedgerTransaction> transactions) {
    final groups = <DateTime, List<LedgerTransaction>>{};
    for (final t in transactions) {
      final local = t.occurredAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(t);
    }

    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        DayGroup(
          day: day,
          transactions: groups[day]!,
          netMinor: groups[day]!.fold(
            0,
            (sum, t) =>
                sum +
                (t.direction == TransactionDirection.credit
                    ? t.amount.minorUnits
                    : -t.amount.minorUnits),
          ),
        ),
    ];
  }
}
