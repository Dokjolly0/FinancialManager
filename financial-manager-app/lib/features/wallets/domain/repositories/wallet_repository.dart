import '../models/wallet.dart';
import '../models/wallet_denomination.dart';
import '../models/wallet_type.dart';

class CreateWalletParams {
  const CreateWalletParams({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.openingBalanceMinor = 0,
  });

  final String name;
  final WalletType type;
  final String icon;
  final String color;
  final int openingBalanceMinor;
}

class UpdateWalletParams {
  const UpdateWalletParams({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.expectedVersion,
  });

  final String name;
  final WalletType type;
  final String icon;
  final String color;
  final int expectedVersion;
}

/// Domain-facing wallet CRUD (plan.md multi-wallet extension). Ledger
/// mutations that also touch a wallet's balance — standard transactions,
/// balance adjustments, transfers — stay in TransactionRepository instead,
/// mirroring how the backend splits these across internal/wallets (pure
/// CRUD) and internal/transactions (ledger + balance orchestration).
abstract class WalletRepository {
  /// Every active (non-archived) wallet for the signed-in user, oldest
  /// first — the picker/list order.
  Future<List<Wallet>> listWallets();

  Future<Wallet> getWallet(String id);

  Future<Wallet> createWallet(CreateWalletParams params);

  Future<Wallet> updateWallet(String id, UpdateWalletParams params);

  /// Soft-deletes the wallet (plan.md: archive-only, never a hard delete —
  /// its transaction history must stay intact for reports/export).
  Future<Wallet> archiveWallet(String id, {required int expectedVersion});

  /// Always returns one row per fixed EUR denomination regardless of
  /// whether the wallet has customized it yet (the backend fills
  /// count=0/enabled=true defaults) — 403s with a WALLET_NOT_CASH domain
  /// error if the wallet isn't a CASH wallet.
  Future<List<WalletDenomination>> getDenominations(String walletId);

  /// Replaces the whole breakdown atomically; the editor always saves the
  /// complete set, never incremental deltas.
  Future<List<WalletDenomination>> replaceDenominations(
    String walletId,
    List<WalletDenomination> denominations,
  );
}
