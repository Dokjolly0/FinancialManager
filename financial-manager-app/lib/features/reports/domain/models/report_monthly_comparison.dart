import '../../../../core/formatting/money.dart';

class MonthlyComparisonRow {
  const MonthlyComparisonRow({
    required this.month,
    required this.credits,
    required this.debits,
    required this.net,
  });

  final DateTime month;
  final Money credits;
  final Money debits;
  final Money net;

  factory MonthlyComparisonRow.fromJson(
    Map<String, dynamic> json,
    String currency,
  ) {
    Money amount(String key) =>
        Money(minorUnits: json[key] as int, currency: currency);
    return MonthlyComparisonRow(
      month: DateTime.parse(json['month'] as String),
      credits: amount('credits_minor'),
      debits: amount('debits_minor'),
      net: amount('net_minor'),
    );
  }
}

/// GET /v1/reports/monthly-comparison (plan.md sections 7.12 "Confronto
/// mensile", 18.7, 18.8). [spansMultipleMonths] is authoritative on
/// whether to show this section at all — the client never re-derives it.
class ReportMonthlyComparison {
  const ReportMonthlyComparison({
    required this.months,
    required this.spansMultipleMonths,
  });

  final List<MonthlyComparisonRow> months;
  final bool spansMultipleMonths;

  factory ReportMonthlyComparison.fromJson(
    Map<String, dynamic> json, {
    required String currency,
  }) {
    final rawMonths = json['months'] as List<dynamic>? ?? [];
    return ReportMonthlyComparison(
      months: rawMonths
          .map(
            (m) => MonthlyComparisonRow.fromJson(
              m as Map<String, dynamic>,
              currency,
            ),
          )
          .toList(),
      spansMultipleMonths: json['spans_multiple_months'] as bool,
    );
  }
}
