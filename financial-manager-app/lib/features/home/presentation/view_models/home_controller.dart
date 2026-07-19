import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../transactions/data/providers.dart';
import '../state/home_state.dart';

/// Loads the wallet balance and recent transactions for the Home screen
/// (plan.md section 7.5). Kept independent of the report/reconciliation
/// machinery — this is a simple "last N operations" view, not an
/// aggregate query.
class HomeController extends Notifier<HomeState> {
  // Seeds balanceObscured from the user's saved "hide balance on open"
  // preference (plan.md section 7.13) the first time the profile becomes
  // available, then gets out of the way — a later profile refetch (e.g.
  // from changing an unrelated setting) must never override a manual
  // toggle the user already made this session. Resets naturally whenever
  // a fresh HomeController is created (sign-in/sign-out, section 20.x
  // account switching), so a new session re-applies its own default.
  bool _appliedDefaultObscured = false;

  @override
  HomeState build() {
    // Refetch whenever any screen mutates the ledger, not just on first
    // load — Home may already be alive in the shell's IndexedStack when a
    // transaction is added from elsewhere.
    ref.listen(ledgerRevisionProvider, (_, _) => refresh());
    ref.listen(accountProfileProvider, (_, next) {
      final profile = next.value;
      if (profile == null || _appliedDefaultObscured) return;
      _appliedDefaultObscured = true;
      state = state.copyWith(balanceObscured: profile.balanceHiddenDefault);
    });
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
    _appliedDefaultObscured = true;
    state = state.copyWith(balanceObscured: !state.balanceObscured);
  }
}

final homeControllerProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
