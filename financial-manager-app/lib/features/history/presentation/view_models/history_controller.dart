import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../transactions/data/providers.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../state/history_state.dart';

const _pageSize = 20;
const _searchDebounce = Duration(milliseconds: 300);

/// Cronologia (plan.md section 7.9, 17): cursor-paginated, filtered ledger
/// list. Refetches from page one whenever any screen mutates the ledger
/// (same cross-feature invalidation as Home, via ledgerRevisionProvider) or
/// whenever the active filter changes.
class HistoryController extends Notifier<HistoryState> {
  Timer? _searchDebounceTimer;

  @override
  HistoryState build() {
    ref.listen(ledgerRevisionProvider, (_, _) => refresh());
    ref.onDispose(() => _searchDebounceTimer?.cancel());
    Future.microtask(refresh);
    return const HistoryState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(transactionRepositoryProvider)
          .listTransactions(limit: _pageSize, filter: state.filter);
      state = state.copyWith(
        isLoading: false,
        transactions: page.transactions,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(transactionRepositoryProvider)
          .listTransactions(
            cursor: state.nextCursor,
            limit: _pageSize,
            filter: state.filter,
          );
      state = state.copyWith(
        isLoadingMore: false,
        transactions: [...state.transactions, ...page.transactions],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } on AppError catch (_) {
      // A "load more" failure isn't worth replacing the whole screen with
      // an error state — the already-loaded page stays visible; the user
      // can retry by scrolling again.
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Debounced per plan.md section 17.3 (250-400ms, min 2 characters for a
  /// remote query — an empty query also refreshes immediately, to clear a
  /// previous search).
  void setSearchQuery(String query) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isNotEmpty && trimmed.length < 2) return;

    _searchDebounceTimer = Timer(_searchDebounce, () {
      applyFilter(
        state.filter.copyWith(title: trimmed, clearTitle: trimmed.isEmpty),
      );
    });
  }

  void applyFilter(TransactionListFilter filter) {
    state = state.copyWith(filter: filter);
    refresh();
  }

  void clearFilters() {
    state = state.copyWith(filter: const TransactionListFilter());
    refresh();
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
