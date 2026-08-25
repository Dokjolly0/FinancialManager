import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../wallets/data/providers.dart';
import '../../../wallets/domain/models/wallet.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionDetailState {
  const TransactionDetailState({
    this.isLoading = true,
    this.transaction,
    this.error,
    this.isDeleting = false,
    this.groupMembers = const [],
  });

  final bool isLoading;
  final LedgerTransaction? transaction;
  final AppError? error;
  final bool isDeleting;

  /// Every transaction sharing [transaction]'s payment group, INCLUDING
  /// itself — empty unless [transaction] has a non-null `paymentGroupId`.
  /// Screens sum over the whole list for the combined total and filter out
  /// [transaction]'s own id when rendering the tappable sibling list.
  final List<LedgerTransaction> groupMembers;

  TransactionDetailState copyWith({
    bool? isLoading,
    LedgerTransaction? transaction,
    AppError? error,
    bool? isDeleting,
    List<LedgerTransaction>? groupMembers,
  }) {
    return TransactionDetailState(
      isLoading: isLoading ?? this.isLoading,
      transaction: transaction ?? this.transaction,
      error: error,
      isDeleting: isDeleting ?? this.isDeleting,
      groupMembers: groupMembers ?? this.groupMembers,
    );
  }
}

class TransactionDetailController extends Notifier<TransactionDetailState> {
  TransactionDetailController(this.arg);

  final String arg;

  @override
  TransactionDetailState build() {
    Future.microtask(load);
    return const TransactionDetailState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final transaction = await repo.getTransaction(arg);
      var groupMembers = const <LedgerTransaction>[];
      if (transaction.paymentGroupId != null) {
        final page = await repo.listTransactions(
          filter: TransactionListFilter(
            paymentGroupId: transaction.paymentGroupId,
          ),
        );
        groupMembers = page.transactions;
      }
      state = state.copyWith(
        isLoading: false,
        transaction: transaction,
        groupMembers: groupMembers,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Returns the wallet after a successful delete, or null on failure
  /// (error is left in state for the screen to show).
  Future<Wallet?> delete() async {
    state = state.copyWith(isDeleting: true, error: null);
    try {
      final wallet = await ref
          .read(transactionRepositoryProvider)
          .deleteTransaction(arg);
      state = state.copyWith(isDeleting: false);
      ref.bumpLedgerRevision();
      ref.invalidate(walletsListProvider);
      return wallet;
    } on AppError catch (e) {
      state = state.copyWith(isDeleting: false, error: e);
      return null;
    }
  }
}

final transactionDetailControllerProvider = NotifierProvider.autoDispose
    .family<TransactionDetailController, TransactionDetailState, String>(
      TransactionDetailController.new,
    );
