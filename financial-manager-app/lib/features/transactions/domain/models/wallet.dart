import '../../../../core/formatting/money.dart';

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.balance,
    required this.version,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final Money balance;
  final int version;
  final DateTime updatedAt;

  static Wallet fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      balance: Money(
        minorUnits: json['current_balance_minor'] as int,
        currency: json['currency'] as String,
      ),
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
