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
    this.categoryId,
    this.templateId,
    this.mediaId,
    required this.occurredAt,
  });

  final TransactionDirection direction;
  final int amountMinor;
  final String currency;
  final String title;
  final String? description;
  final String? categoryId;
  final String? templateId;
  final String? mediaId;
  final DateTime occurredAt;
}

class UpdateTransactionParams {
  const UpdateTransactionParams({
    required this.direction,
    required this.amountMinor,
    required this.title,
    this.description,
    this.categoryId,
    this.templateId,
    this.mediaId,
    required this.occurredAt,
    required this.expectedVersion,
  });

  final TransactionDirection direction;
  final int amountMinor;
  final String title;
  final String? description;
  final String? categoryId;
  final String? templateId;
  final String? mediaId;
  final DateTime occurredAt;
  final int expectedVersion;
}

/// Which transaction kinds a history query should include (plan.md section
/// 7.9 "Tipo: tutte, uscite, entrate, rettifiche"). [all] means no
/// direction/kind filter at all — STANDARD, OPENING_BALANCE, and
/// BALANCE_ADJUSTMENT rows all show up, each with their own tile styling.
enum TransactionTypeFilter { all, debit, credit, adjustments }

/// Filters for [TransactionRepository.listTransactions] (plan.md section
/// 7.9, 17.1). All fields are optional; a `null`/empty field means
/// "unfiltered" for that dimension.
class TransactionListFilter {
  const TransactionListFilter({
    this.type = TransactionTypeFilter.all,
    this.title,
    this.categoryId,
    this.amountMinMinor,
    this.amountMaxMinor,
    this.occurredFrom,
    this.occurredTo,
  });

  final TransactionTypeFilter type;
  final String? title;
  final String? categoryId;
  final int? amountMinMinor;
  final int? amountMaxMinor;
  final DateTime? occurredFrom;
  final DateTime? occurredTo;

  int get activeCount {
    var count = 0;
    if (type != TransactionTypeFilter.all) count++;
    if (title != null && title!.isNotEmpty) count++;
    if (categoryId != null) count++;
    if (amountMinMinor != null) count++;
    if (amountMaxMinor != null) count++;
    if (occurredFrom != null) count++;
    if (occurredTo != null) count++;
    return count;
  }

  /// Each optional field has a matching `clearX` flag since `?? this.x`
  /// alone can't distinguish "leave unchanged" from "clear back to null".
  TransactionListFilter copyWith({
    TransactionTypeFilter? type,
    String? title,
    bool clearTitle = false,
    String? categoryId,
    bool clearCategoryId = false,
    int? amountMinMinor,
    bool clearAmountMinMinor = false,
    int? amountMaxMinor,
    bool clearAmountMaxMinor = false,
    DateTime? occurredFrom,
    bool clearOccurredFrom = false,
    DateTime? occurredTo,
    bool clearOccurredTo = false,
  }) {
    return TransactionListFilter(
      type: type ?? this.type,
      title: clearTitle ? null : (title ?? this.title),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      amountMinMinor: clearAmountMinMinor
          ? null
          : (amountMinMinor ?? this.amountMinMinor),
      amountMaxMinor: clearAmountMaxMinor
          ? null
          : (amountMaxMinor ?? this.amountMaxMinor),
      occurredFrom: clearOccurredFrom
          ? null
          : (occurredFrom ?? this.occurredFrom),
      occurredTo: clearOccurredTo ? null : (occurredTo ?? this.occurredTo),
    );
  }
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
    TransactionListFilter filter = const TransactionListFilter(),
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
