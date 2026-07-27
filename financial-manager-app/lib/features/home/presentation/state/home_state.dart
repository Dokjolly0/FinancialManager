import '../../../../core/errors/app_error.dart';
import '../../../../core/formatting/money.dart';
import '../../../transactions/domain/models/ledger_transaction.dart';
import '../../../wallets/domain/models/wallet.dart';

class HomeState {
  const HomeState({
    this.isLoading = true,
    this.wallets = const [],
    this.recentTransactions = const [],
    this.error,
    this.balanceObscured = false,
  });

  final bool isLoading;

  /// Every active wallet the user owns (plan.md's Home redesign: aggregate
  /// total + per-wallet list below, replacing the old single-wallet card).
  final List<Wallet> wallets;
  final List<LedgerTransaction> recentTransactions;
  final AppError? error;
  final bool balanceObscured;

  Money get totalBalance => wallets.isEmpty
      ? Money.zeroEur
      : wallets.map((w) => w.balance).reduce((a, b) => a + b);

  HomeState copyWith({
    bool? isLoading,
    List<Wallet>? wallets,
    List<LedgerTransaction>? recentTransactions,
    AppError? error,
    bool? balanceObscured,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      wallets: wallets ?? this.wallets,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      error: error,
      balanceObscured: balanceObscured ?? this.balanceObscured,
    );
  }
}
