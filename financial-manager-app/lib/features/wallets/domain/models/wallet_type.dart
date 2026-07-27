/// A wallet's category (plan.md multi-wallet extension): purely
/// informational, drives which icon defaults/features (cash denominations)
/// apply, never affects ledger math.
enum WalletType {
  cash,
  bank,
  other;

  static WalletType fromApi(String value) => switch (value) {
    'CASH' => WalletType.cash,
    'BANK' => WalletType.bank,
    'OTHER' => WalletType.other,
    _ => WalletType.other,
  };

  String toApi() => switch (this) {
    WalletType.cash => 'CASH',
    WalletType.bank => 'BANK',
    WalletType.other => 'OTHER',
  };
}

/// Fixed in-app icon keys a wallet may reference, matching the backend's
/// ValidIcons set exactly (internal/wallets/wallet.go) — the client owns
/// the actual IconData lookup (presentation layer), this list just bounds
/// what's selectable.
const List<String> walletIconKeys = [
  'wallet',
  'cash',
  'bank',
  'card',
  'piggy_bank',
  'safe',
  'coins',
  'briefcase',
  'gift',
  'shopping_bag',
  'home',
  'savings',
];

const String defaultWalletIcon = 'wallet';
const String defaultWalletColor = '#6750A4';
