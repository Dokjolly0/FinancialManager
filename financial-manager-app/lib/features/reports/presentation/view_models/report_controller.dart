import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../data/providers.dart';
import '../../domain/models/report_period.dart';
import '../../domain/repositories/report_repository.dart';
import '../state/report_state.dart';

/// Report (plan.md section 7.12): fetches the four report endpoints for
/// the current period/toggle, refetching whenever the ledger changes
/// elsewhere in the app (same cross-feature invalidation as History/Home,
/// via ledgerRevisionProvider).
class ReportController extends Notifier<ReportState> {
  @override
  ReportState build() {
    ref.listen(ledgerRevisionProvider, (_, _) => refresh());
    Future.microtask(refresh);
    return const ReportState();
  }

  ReportQuery get _query =>
      ReportQuery(period: state.period, includeAdjustments: state.includeAdjustments);

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final query = _query;
      // Kicked off together (each call starts its HTTP request before this
      // line moves on) and only then awaited in order, so the four
      // endpoints load in parallel without a heterogeneous Future.wait.
      final summaryFuture = repo.summary(query);
      final timeseriesFuture = repo.timeseries(query);
      final breakdownFuture = repo.breakdown(query, groupBy: state.groupBy);
      final monthlyFuture = repo.monthlyComparison(query);

      final summary = await summaryFuture;
      final timeseries = await timeseriesFuture;
      final breakdown = await breakdownFuture;
      final monthlyComparison = await monthlyFuture;

      state = state.copyWith(
        isLoading: false,
        summary: summary,
        timeseries: timeseries,
        breakdown: breakdown,
        monthlyComparison: monthlyComparison,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> _refreshBreakdown() async {
    state = state.copyWith(isBreakdownLoading: true);
    try {
      final breakdown = await ref
          .read(reportRepositoryProvider)
          .breakdown(_query, groupBy: state.groupBy);
      state = state.copyWith(isBreakdownLoading: false, breakdown: breakdown);
    } on AppError catch (_) {
      // Keep whatever breakdown was already showing rather than blanking
      // the whole screen for a tab-switch failure.
      state = state.copyWith(isBreakdownLoading: false);
    }
  }

  void setPreset(ReportPreset preset) {
    if (preset == ReportPreset.custom) {
      state = state.copyWith(period: state.period.copyWith(preset: preset));
      return;
    }
    state = state.copyWith(period: ReportPeriodSelection(preset: preset));
    refresh();
  }

  void setCustomRange(DateTime from, DateTime to) {
    state = state.copyWith(
      period: ReportPeriodSelection(
        preset: ReportPreset.custom,
        customFrom: from,
        customTo: to,
      ),
    );
    refresh();
  }

  void toggleIncludeAdjustments(bool value) {
    state = state.copyWith(includeAdjustments: value);
    refresh();
  }

  void setGroupBy(String groupBy) {
    if (groupBy == state.groupBy) return;
    state = state.copyWith(groupBy: groupBy);
    _refreshBreakdown();
  }
}

final reportControllerProvider =
    NotifierProvider<ReportController, ReportState>(ReportController.new);
