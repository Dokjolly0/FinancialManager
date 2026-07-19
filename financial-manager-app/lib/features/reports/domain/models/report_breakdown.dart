import '../../../../core/formatting/money.dart';

class BreakdownItem {
  const BreakdownItem({
    required this.key,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
  });

  final String key;
  final String label;
  final Money amount;
  final double percentage;
  final int transactionCount;

  bool get isOther => key == 'other';

  factory BreakdownItem.fromJson(Map<String, dynamic> json, String currency) {
    return BreakdownItem(
      key: json['key'] as String,
      label: json['label'] as String,
      amount: Money(minorUnits: json['amount_minor'] as int, currency: currency),
      percentage: (json['percentage'] as num).toDouble(),
      transactionCount: json['transaction_count'] as int,
    );
  }
}

/// GET /v1/reports/breakdown (plan.md sections 7.12 "Ripartizione", 18.4,
/// 18.5). Credits and debits are separate lists with independent
/// denominators — never merge them into one chart.
class ReportBreakdown {
  const ReportBreakdown({
    required this.groupBy,
    required this.credits,
    required this.debits,
  });

  final String groupBy;
  final List<BreakdownItem> credits;
  final List<BreakdownItem> debits;

  factory ReportBreakdown.fromJson(
    Map<String, dynamic> json, {
    required String currency,
  }) {
    List<BreakdownItem> items(String key) =>
        (json[key] as List<dynamic>? ?? [])
            .map(
              (i) => BreakdownItem.fromJson(i as Map<String, dynamic>, currency),
            )
            .toList();
    return ReportBreakdown(
      groupBy: json['group_by'] as String,
      credits: items('credits'),
      debits: items('debits'),
    );
  }
}
