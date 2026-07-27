import '../../../../core/formatting/money.dart';
import 'transaction_direction.dart';

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.walletId,
    required this.direction,
    required this.kind,
    required this.amount,
    required this.title,
    this.description,
    this.categoryId,
    this.templateId,
    this.mediaId,
    this.transferPairId,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String walletId;
  final TransactionDirection direction;
  final TransactionKind kind;
  final Money amount;
  final String title;
  final String? description;
  final String? categoryId;
  final String? templateId;
  final String? mediaId;
  final String? transferPairId;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isEditable => kind == TransactionKind.standard;

  /// Whether this row's amount/date can be corrected through the dedicated
  /// opening-balance edit sheet (never the full transaction form — see
  /// [TransactionKind]'s doc comment for what stays fixed).
  bool get isOpeningBalanceEditable => kind == TransactionKind.openingBalance;

  static LedgerTransaction fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      direction: TransactionDirection.fromApi(json['direction'] as String),
      kind: TransactionKind.fromApi(json['kind'] as String),
      amount: Money(
        minorUnits: json['amount_minor'] as int,
        currency: json['currency'] as String,
      ),
      title: json['title'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      templateId: json['template_id'] as String?,
      mediaId: json['media_id'] as String?,
      transferPairId: json['transfer_pair_id'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}
