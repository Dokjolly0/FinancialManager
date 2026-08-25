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
    this.linkedTransactionId,
    this.systemGenerated = false,
    this.paymentGroupId,
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

  /// Pairs a meal-voucher expense's two DEBIT legs (the voucher-wallet leg
  /// and, if the vouchers didn't cover the full expense, the other-wallet
  /// leg for the difference) — a generic analogue of [transferPairId] that
  /// stays [TransactionKind.standard]. Null on a fully-covered voucher
  /// expense (no second leg), so it alone can't identify every voucher
  /// expense — see [VoucherExpenseSheet]'s callers, which also check the
  /// transaction's wallet type.
  final String? linkedTransactionId;

  /// True only for the automatic "Buoni scaduti" voucher-expiry write-off —
  /// never created or editable by the user.
  final bool systemGenerated;

  /// Groups two or more STANDARD transactions the user has explicitly
  /// linked as installments of the same logical expense (e.g. an acconto
  /// followed by a saldo) — "pagamenti collegati". Unlike
  /// [linkedTransactionId], this isn't a pointer to one specific sibling:
  /// every member of the group shares this same value, has no accounting
  /// effect, and stays independently editable/deletable — it's purely a
  /// display/navigation grouping (see [TransactionDetailController], which
  /// fetches every transaction sharing this id).
  final String? paymentGroupId;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  /// A voucher expense's other-wallet (shortfall) leg is also
  /// [TransactionKind.standard] but must only be edited/deleted as part of
  /// its pair through [VoucherExpenseSheet], never the plain transaction
  /// form — [linkedTransactionId] alone identifies that leg (the
  /// voucher-wallet leg needs an additional wallet-type check, done by
  /// callers that have access to the wallet list).
  bool get isEditable =>
      kind == TransactionKind.standard &&
      linkedTransactionId == null &&
      !systemGenerated;

  /// Whether this row's amount/date can be corrected through the dedicated
  /// opening-balance edit sheet (never the full transaction form — see
  /// [TransactionKind]'s doc comment for what stays fixed).
  bool get isOpeningBalanceEditable => kind == TransactionKind.openingBalance;

  /// Whether this row's amount/date can be corrected through the dedicated
  /// transfer edit sheet — never the source/destination wallets, which are
  /// structural to the linked DEBIT/CREDIT pair (see [TransactionKind]'s
  /// doc comment).
  bool get isTransferEditable => kind == TransactionKind.transfer;

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
      linkedTransactionId: json['linked_transaction_id'] as String?,
      systemGenerated: json['system_generated'] as bool? ?? false,
      paymentGroupId: json['payment_group_id'] as String?,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int,
    );
  }
}
