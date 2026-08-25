import '../../../../core/formatting/money.dart';
import 'wallet_type.dart';

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.type,
    required this.icon,
    required this.color,
    required this.version,
    required this.updatedAt,
    this.archivedAt,
    this.voucherUnitValueMinor,
    this.voucherExpiryCutoffMonth,
    this.voucherExpiryMonth,
    this.voucherExpiryDay,
    this.voucherExpiringSoonCount,
  });

  final String id;
  final String name;
  final Money balance;
  final WalletType type;
  final String icon;
  final String color;
  final int version;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  /// Only set when [type] is [WalletType.mealVoucher] — the face value of
  /// one voucher, fixed at wallet creation (never editable afterwards).
  final int? voucherUnitValueMinor;

  /// The wallet's voucher expiry policy (backend wallets.ComputeLotExpiry):
  /// a voucher loaded in a month at or before [voucherExpiryCutoffMonth]
  /// expires on [voucherExpiryMonth]/[voucherExpiryDay] of the same year;
  /// loaded after, of the following year. Editable after creation, unlike
  /// [voucherUnitValueMinor].
  final int? voucherExpiryCutoffMonth;
  final int? voucherExpiryMonth;
  final int? voucherExpiryDay;

  /// Count of active voucher lots expiring within 30 days — only populated
  /// by [WalletRepository.listWallets]/`getWallet` (the wallet-list badge),
  /// null after a mutation echoes a wallet back.
  final int? voucherExpiringSoonCount;

  bool get isArchived => archivedAt != null;
  bool get isMealVoucher => type == WalletType.mealVoucher;

  static Wallet fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      balance: Money(
        minorUnits: json['current_balance_minor'] as int,
        currency: json['currency'] as String,
      ),
      type: WalletType.fromApi(json['type'] as String),
      icon: json['icon'] as String,
      color: json['color'] as String,
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      voucherUnitValueMinor: json['voucher_unit_value_minor'] as int?,
      voucherExpiryCutoffMonth: json['voucher_expiry_cutoff_month'] as int?,
      voucherExpiryMonth: json['voucher_expiry_month'] as int?,
      voucherExpiryDay: json['voucher_expiry_day'] as int?,
      voucherExpiringSoonCount: json['voucher_expiring_soon_count'] as int?,
    );
  }
}
