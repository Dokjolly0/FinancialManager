import '../../../../core/formatting/money.dart';

/// One row of the "pagamenti collegati" list (plan.md linked-transactions
/// feature): a group of 2+ transactions the user has linked as installments
/// of the same logical expense. Nothing here is denormalized server-side —
/// the representative (the earliest member) is recomputed on every read, so
/// this can never go stale.
class PaymentGroupSummary {
  const PaymentGroupSummary({
    required this.paymentGroupId,
    required this.memberCount,
    required this.netAmount,
    required this.representativeTransactionId,
    required this.representativeTitle,
  });

  final String paymentGroupId;
  final int memberCount;
  final Money netAmount;
  final String representativeTransactionId;
  final String representativeTitle;

  static PaymentGroupSummary fromJson(Map<String, dynamic> json) {
    return PaymentGroupSummary(
      paymentGroupId: json['payment_group_id'] as String,
      memberCount: json['member_count'] as int,
      netAmount: Money(
        minorUnits: json['net_amount_minor'] as int,
        currency: json['currency'] as String,
      ),
      representativeTransactionId:
          json['representative_transaction_id'] as String,
      representativeTitle: json['representative_title'] as String,
    );
  }
}
