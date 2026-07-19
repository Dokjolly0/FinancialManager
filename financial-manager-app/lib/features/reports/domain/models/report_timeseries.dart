import '../../../../core/formatting/money.dart';

class TimeseriesPoint {
  const TimeseriesPoint({
    required this.periodStart,
    required this.credits,
    required this.debits,
    required this.net,
    required this.balance,
  });

  final DateTime periodStart;
  final Money credits;
  final Money debits;
  final Money net;
  final Money balance;

  factory TimeseriesPoint.fromJson(Map<String, dynamic> json, String currency) {
    Money amount(String key) =>
        Money(minorUnits: json[key] as int, currency: currency);
    return TimeseriesPoint(
      periodStart: DateTime.parse(json['period_start'] as String),
      credits: amount('credits_minor'),
      debits: amount('debits_minor'),
      net: amount('net_minor'),
      balance: amount('balance_minor'),
    );
  }
}

/// GET /v1/reports/timeseries (plan.md sections 7.12 "Grafico andamento",
/// 18.7). Granularity is decided by the backend, never recomputed here.
class ReportTimeseries {
  const ReportTimeseries({required this.granularity, required this.points});

  final String granularity;
  final List<TimeseriesPoint> points;

  bool get isMonthly => granularity == 'monthly';

  factory ReportTimeseries.fromJson(
    Map<String, dynamic> json, {
    required String currency,
  }) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    return ReportTimeseries(
      granularity: json['granularity'] as String,
      points: rawPoints
          .map(
            (p) =>
                TimeseriesPoint.fromJson(p as Map<String, dynamic>, currency),
          )
          .toList(),
    );
  }
}
