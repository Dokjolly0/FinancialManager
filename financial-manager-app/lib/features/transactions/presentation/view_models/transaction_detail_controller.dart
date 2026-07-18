import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/wallet.dart';

class TransactionDetailState {
  const TransactionDetailState({
    this.isLoading = true,
    this.transaction,
    this.error,
    this.isDeleting = false,
  });

  final bool isLoading;
  final LedgerTransaction? transaction;
  final String? error;
  final bool isDeleting;

  TransactionDetailState copyWith({
    bool? isLoading,
    LedgerTransaction? transaction,
    String? error,
    bool? isDeleting,
  }) {
    return TransactionDetailState(
      isLoading: isLoading ?? this.isLoading,
      transaction: transaction ?? this.transaction,
      error: error,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

class TransactionDetailController
    extends AutoDisposeFamilyNotifier<TransactionDetailState, String> {
  @override
  TransactionDetailState build(String arg) {
    Future.microtask(load);
    return const TransactionDetailState();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final transaction = await ref
          .read(transactionRepositoryProvider)
          .getTransaction(arg);
      state = state.copyWith(isLoading: false, transaction: transaction);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: presentError(e).message);
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
      return wallet;
    } on AppError catch (e) {
      state = state.copyWith(isDeleting: false, error: presentError(e).message);
      return null;
    }
  }
}

final transactionDetailControllerProvider = NotifierProvider.autoDispose
    .family<TransactionDetailController, TransactionDetailState, String>(
      TransactionDetailController.new,
    );
