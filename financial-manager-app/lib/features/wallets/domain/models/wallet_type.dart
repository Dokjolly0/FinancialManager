/// A wallet's category (plan.md multi-wallet extension): purely
/// informational, drives which icon defaults/features (cash denominations)
/// apply, never affects ledger math.
enum WalletType {
  cash,
  bank,
  other,
  mealVoucher;

  static WalletType fromApi(String value) => switch (value) {
    'CASH' => WalletType.cash,
    'BANK' => WalletType.bank,
    'MEAL_VOUCHER' => WalletType.mealVoucher,
    'OTHER' => WalletType.other,
    _ => WalletType.other,
  };

  String toApi() => switch (this) {
    WalletType.cash => 'CASH',
    WalletType.bank => 'BANK',
    WalletType.other => 'OTHER',
    WalletType.mealVoucher => 'MEAL_VOUCHER',
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
  'restaurant',
];

const String defaultWalletIcon = 'wallet';
const String defaultWalletColor = '#6750A4';

/// Meal-voucher expiry policy defaults (mirrors
/// wallets.DefaultVoucherExpiry* in the backend): vouchers loaded
/// January-August expire December 31 of the same year; loaded
/// September-December, December 31 of the following year.
const int defaultVoucherExpiryCutoffMonth = 8;
const int defaultVoucherExpiryMonth = 12;
const int defaultVoucherExpiryDay = 31;
