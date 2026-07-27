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

  bool get isArchived => archivedAt != null;

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
    );
  }
}
