import '../../../../core/errors/app_error.dart';
import '../../../transactions/domain/models/ledger_transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';

class HistoryState {
  const HistoryState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.transactions = const [],
    this.nextCursor,
    this.hasMore = false,
    this.error,
    this.filter = const TransactionListFilter(),
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<LedgerTransaction> transactions;
  final String? nextCursor;
  final bool hasMore;
  final AppError? error;
  final TransactionListFilter filter;

  bool get hasActiveFilters => filter.activeCount > 0;

  HistoryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<LedgerTransaction>? transactions,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    AppError? error,
    bool clearError = false,
    TransactionListFilter? filter,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      transactions: transactions ?? this.transactions,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}
