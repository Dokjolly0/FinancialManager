import '../../../wallets/domain/models/wallet.dart';
import '../models/ledger_transaction.dart';
import '../models/transaction_direction.dart';
import '../models/transaction_page.dart';

class CreateTransactionParams {
  const CreateTransactionParams({
    required this.walletId,
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

  final String walletId;
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
    required this.walletId,
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

  /// The wallet the transaction should belong to after this update. If it
  /// differs from the transaction's current wallet, the backend moves it —
  /// this project's product decision explicitly allows changing a
  /// transaction's wallet on edit (unlike most other fixed-at-creation
  /// choices).
  final String walletId;
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
/// direction/kind filter at all — STANDARD, OPENING_BALANCE,
/// BALANCE_ADJUSTMENT, and TRANSFER rows all show up, each with their own
/// tile styling. [transfers] isolates TRANSFER-kind rows, which otherwise
/// blend into [debit]/[credit] results.
enum TransactionTypeFilter { all, debit, credit, adjustments, transfers }

/// Filters for [TransactionRepository.listTransactions] (plan.md section
/// 7.9, 17.1). All fields are optional; a `null`/empty field means
/// "unfiltered" for that dimension.
class TransactionListFilter {
  const TransactionListFilter({
    this.type = TransactionTypeFilter.all,
    this.walletId,
    this.title,
    this.categoryId,
    this.amountMinMinor,
    this.amountMaxMinor,
    this.occurredFrom,
    this.occurredTo,
  });

  final TransactionTypeFilter type;

  /// `null` means unfiltered — every wallet's transactions show up
  /// together, matching plan.md's default history view.
  final String? walletId;
  final String? title;
  final String? categoryId;
  final int? amountMinMinor;
  final int? amountMaxMinor;
  final DateTime? occurredFrom;
  final DateTime? occurredTo;

  int get activeCount {
    var count = 0;
    if (type != TransactionTypeFilter.all) count++;
    if (walletId != null) count++;
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
    String? walletId,
    bool clearWalletId = false,
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
      walletId: clearWalletId ? null : (walletId ?? this.walletId),
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

  /// The wallet's OPENING_BALANCE row, or null if it has none — a wallet
  /// created with a zero opening balance never gets one (the transactions
  /// table's amount_minor > 0 constraint), so there's nothing to edit.
  Future<LedgerTransaction?> getOpeningBalanceTransaction(String walletId);

  Future<TransactionPage> listTransactions({
    String? cursor,
    int limit = 20,
    TransactionListFilter filter = const TransactionListFilter(),
  });

  Future<TransactionWithWallet> updateStandard(
    String id,
    UpdateTransactionParams params,
  );

  /// Edits a wallet's OPENING_BALANCE entry — amount and date only, never
  /// wallet/title/category/direction (those are structural to what makes it
  /// an opening balance rather than an ordinary transaction).
  Future<TransactionWithWallet> updateOpeningBalance(
    String id, {
    required int amountMinor,
    required DateTime occurredAt,
    required int expectedVersion,
  });

  /// Returns the wallet's new balance after reversing the deleted
  /// transaction's effect.
  Future<Wallet> deleteTransaction(String id);

  /// Sets [walletId]'s balance to [targetBalanceMinor]; the backend
  /// computes the delta and creates a BALANCE_ADJUSTMENT entry for it
  /// (plan.md section 13.5).
  Future<TransactionWithWallet> createBalanceAdjustment({
    required String walletId,
    required int targetBalanceMinor,
    String? reason,
  });

  /// Atomically moves money from one wallet to another: a linked DEBIT/
  /// CREDIT pair of kind=TRANSFER, excluded from expense/income report
  /// totals (plan.md's "aggiunta o ricarica di credito da un conto ad un
  /// altro").
  Future<TransferResult> createTransfer({
    required String sourceWalletId,
    required String destinationWalletId,
    required int amountMinor,
    String? note,
    DateTime? occurredAt,
  });

  /// Edits a transfer's amount and date only — never the source/destination
  /// wallets, which are structural to the linked DEBIT/CREDIT pair. [id]
  /// may be either leg (the transaction list shows one row per wallet), and
  /// [expectedVersion] is that leg's version; the backend locates and
  /// updates its pair together so the two rows never drift out of sync.
  Future<TransferResult> updateTransfer(
    String id, {
    required int amountMinor,
    required DateTime occurredAt,
    required int expectedVersion,
  });
}

/// What a transfer returns: both ledger legs plus both wallets' new
/// authoritative balances — the client never computes them itself.
class TransferResult {
  const TransferResult({
    required this.debitTransaction,
    required this.creditTransaction,
    required this.sourceWallet,
    required this.destinationWallet,
  });

  final LedgerTransaction debitTransaction;
  final LedgerTransaction creditTransaction;
  final Wallet sourceWallet;
  final Wallet destinationWallet;
}
