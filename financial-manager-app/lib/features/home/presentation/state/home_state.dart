import '../../../transactions/domain/models/ledger_transaction.dart';
import '../../../transactions/domain/models/wallet.dart';

class HomeState {
  const HomeState({
    this.isLoading = true,
    this.wallet,
    this.recentTransactions = const [],
    this.error,
    this.balanceObscured = false,
  });

  final bool isLoading;
  final Wallet? wallet;
  final List<LedgerTransaction> recentTransactions;
  final String? error;
  final bool balanceObscured;

  HomeState copyWith({
    bool? isLoading,
    Wallet? wallet,
    List<LedgerTransaction>? recentTransactions,
    String? error,
    bool? balanceObscured,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      wallet: wallet ?? this.wallet,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      error: error,
      balanceObscured: balanceObscured ?? this.balanceObscured,
    );
  }
}
