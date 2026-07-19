import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../transactions/data/providers.dart';
import '../state/home_state.dart';

/// Loads the wallet balance and recent transactions for the Home screen
/// (plan.md section 7.5). Kept independent of the report/reconciliation
/// machinery — this is a simple "last N operations" view, not an
/// aggregate query.
class HomeController extends Notifier<HomeState> {
  @override
  HomeState build() {
    // Refetch whenever any screen mutates the ledger, not just on first
    // load — Home may already be alive in the shell's IndexedStack when a
    // transaction is added from elsewhere.
    ref.listen(ledgerRevisionProvider, (_, _) => refresh());
    Future.microtask(refresh);
    return const HomeState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final wallet = await ref.read(walletRepositoryProvider).getWallet();
      final page = await ref
          .read(transactionRepositoryProvider)
          .listTransactions(limit: 8);
      state = state.copyWith(
        isLoading: false,
        wallet: wallet,
        recentTransactions: page.transactions,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void toggleBalanceObscured() {
    state = state.copyWith(balanceObscured: !state.balanceObscured);
  }
}

final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
