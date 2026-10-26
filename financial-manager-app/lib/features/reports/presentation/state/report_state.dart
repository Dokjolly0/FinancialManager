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
    this.walletId,
    this.isLoading = false,
    this.error,
    this.summary,
    this.timeseries,
    this.breakdown,
    this.monthlyComparison,
  });

  final ReportPeriodSelection period;
  final bool includeAdjustments;

  /// `null` means the reports wallet selector is set to "all wallets"
  /// (plan.md's explicit requirement for a selector, not just an
  /// aggregate-only view).
  final String? walletId;
  final bool isLoading;
  final AppError? error;
  final ReportSummary? summary;
  final ReportTimeseries? timeseries;
  final ReportBreakdown? breakdown;
  final ReportMonthlyComparison? monthlyComparison;

  bool get hasData => summary != null;

  ReportState copyWith({
    ReportPeriodSelection? period,
    bool? includeAdjustments,
    String? walletId,
    bool clearWalletId = false,
    bool? isLoading,
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
      walletId: clearWalletId ? null : (walletId ?? this.walletId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      summary: summary ?? this.summary,
      timeseries: timeseries ?? this.timeseries,
      breakdown: breakdown ?? this.breakdown,
      monthlyComparison: monthlyComparison ?? this.monthlyComparison,
    );
  }
}

/// The backend's group_by the reports use (plan.md section 18.5). The API
/// also groups by title, but the screen doesn't offer it: most titles are
/// typed by hand and differ, so it made a long list of 1–2% entries.
abstract final class ReportGroupBy {
  static const category = 'category';
}
