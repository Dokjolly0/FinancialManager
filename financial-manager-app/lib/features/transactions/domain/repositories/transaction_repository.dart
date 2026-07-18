import '../models/ledger_transaction.dart';
import '../models/transaction_direction.dart';
import '../models/transaction_page.dart';
import '../models/wallet.dart';

class CreateTransactionParams {
  const CreateTransactionParams({
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.title,
    this.description,
    required this.occurredAt,
  });

  final TransactionDirection direction;
  final int amountMinor;
  final String currency;
  final String title;
  final String? description;
  final DateTime occurredAt;
}

class UpdateTransactionParams {
  const UpdateTransactionParams({
    required this.direction,
    required this.amountMinor,
    required this.title,
    this.description,
    required this.occurredAt,
    required this.expectedVersion,
  });

  final TransactionDirection direction;
  final int amountMinor;
  final String title;
  final String? description;
  final DateTime occurredAt;
  final int expectedVersion;
}

/// Domain-facing ledger operations (plan.md section 14.5). The
/// presentation layer never talks to Dio or the backend's JSON shape
/// directly.
abstract class TransactionRepository {
  Future<TransactionWithWallet> createStandard(CreateTransactionParams params);

  Future<LedgerTransaction> getTransaction(String id);

  Future<TransactionPage> listTransactions({
    String? cursor,
    int limit = 20,
    TransactionDirection? direction,
  });

  Future<TransactionWithWallet> updateStandard(
    String id,
    UpdateTransactionParams params,
  );

  /// Returns the wallet's new balance after reversing the deleted
  /// transaction's effect.
  Future<Wallet> deleteTransaction(String id);

  /// Sets the wallet's balance to [targetBalanceMinor]; the backend
  /// computes the delta and creates a BALANCE_ADJUSTMENT entry for it
  /// (plan.md section 13.5).
  Future<TransactionWithWallet> createBalanceAdjustment({
    required int targetBalanceMinor,
    String? reason,
  });
}
