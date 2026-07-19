import '../models/report_breakdown.dart';
import '../models/report_monthly_comparison.dart';
import '../models/report_period.dart';
import '../models/report_summary.dart';
import '../models/report_timeseries.dart';

/// Parameters shared by every report endpoint (plan.md section 14.9). The
/// device's local timezone isn't sent — the backend already defaults to
/// the user's profile timezone set at registration.
class ReportQuery {
  const ReportQuery({required this.period, this.includeAdjustments = false});

  final ReportPeriodSelection period;
  final bool includeAdjustments;
}

abstract class ReportRepository {
  Future<ReportSummary> summary(ReportQuery query);
  Future<ReportTimeseries> timeseries(ReportQuery query);
  Future<ReportBreakdown> breakdown(
    ReportQuery query, {
    required String groupBy,
  });
  Future<ReportMonthlyComparison> monthlyComparison(ReportQuery query);
}
