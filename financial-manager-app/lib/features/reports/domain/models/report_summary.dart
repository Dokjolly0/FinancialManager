import '../../../../core/formatting/money.dart';

/// GET /v1/reports/summary (plan.md sections 7.12, 18.3).
class ReportSummary {
  const ReportSummary({
    required this.openingBalance,
    required this.closingBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.net,
    required this.savingsRatePercent,
    required this.transactionCount,
  });

  final Money openingBalance;
  final Money closingBalance;
  final Money totalCredits;
  final Money totalDebits;
  final Money net;
  final double? savingsRatePercent;
  final int transactionCount;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'] as String;
    Money amount(String key) =>
        Money(minorUnits: json[key] as int, currency: currency);
    return ReportSummary(
      openingBalance: amount('opening_balance_minor'),
      closingBalance: amount('closing_balance_minor'),
      totalCredits: amount('total_credits_minor'),
      totalDebits: amount('total_debits_minor'),
      net: amount('net_minor'),
      savingsRatePercent: (json['savings_rate_percent'] as num?)?.toDouble(),
      transactionCount: json['transaction_count'] as int,
    );
  }
}
