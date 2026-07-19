import '../../../../core/errors/app_error.dart';
import '../../domain/models/report_breakdown.dart';
import '../../domain/models/report_monthly_comparison.dart';
import '../../domain/models/report_period.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/models/report_timeseries.dart';

class ReportState {
  const ReportState({
    this.period = const ReportPeriodSelection(),
    this.includeAdjustments = false,
    this.groupBy = ReportGroupBy.title,
    this.isLoading = false,
    this.isBreakdownLoading = false,
    this.error,
    this.summary,
    this.timeseries,
    this.breakdown,
    this.monthlyComparison,
  });

  final ReportPeriodSelection period;
  final bool includeAdjustments;
  final String groupBy;
  final bool isLoading;
  final bool isBreakdownLoading;
  final AppError? error;
  final ReportSummary? summary;
  final ReportTimeseries? timeseries;
  final ReportBreakdown? breakdown;
  final ReportMonthlyComparison? monthlyComparison;

  bool get hasData => summary != null;

  ReportState copyWith({
    ReportPeriodSelection? period,
    bool? includeAdjustments,
    String? groupBy,
    bool? isLoading,
    bool? isBreakdownLoading,
    AppError? error,
    bool clearError = false,
    ReportSummary? summary,
    ReportTimeseries? timeseries,
    ReportBreakdown? breakdown,
    ReportMonthlyComparison? monthlyComparison,
  }) {
    return ReportState(
      period: period ?? this.period,
      includeAdjustments: includeAdjustments ?? this.includeAdjustments,
      groupBy: groupBy ?? this.groupBy,
      isLoading: isLoading ?? this.isLoading,
      isBreakdownLoading: isBreakdownLoading ?? this.isBreakdownLoading,
      error: clearError ? null : (error ?? this.error),
      summary: summary ?? this.summary,
      timeseries: timeseries ?? this.timeseries,
      breakdown: breakdown ?? this.breakdown,
      monthlyComparison: monthlyComparison ?? this.monthlyComparison,
    );
  }
}

/// Mirrors the backend's group_by values (plan.md section 18.4/18.5).
abstract final class ReportGroupBy {
  static const title = 'title';
  static const category = 'category';
}
