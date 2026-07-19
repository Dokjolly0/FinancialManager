import '../../../../core/formatting/money.dart';
import 'transaction_direction.dart';

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.direction,
    required this.kind,
    required this.amount,
    required this.title,
    this.description,
    this.categoryId,
    this.templateId,
    this.mediaId,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final TransactionDirection direction;
  final TransactionKind kind;
  final Money amount;
  final String title;
  final String? description;
  final String? categoryId;
  final String? templateId;
  final String? mediaId;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  bool get isEditable => kind == TransactionKind.standard;

  static LedgerTransaction fromJson(Map<String, dynamic> json) {
    return LedgerTransaction(
      id: json['id'] as String,
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
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}
