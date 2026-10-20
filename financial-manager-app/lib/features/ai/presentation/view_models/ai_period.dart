import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reports/domain/models/report_period.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/models/ai_analysis_request.dart';

/// Shortcuts on the setup screen. Each fills the From/To fields with
/// concrete dates; [allTime] clears both.
enum AiQuickPeriod {
  last30Days,
  currentMonth,
  lastMonth,
  lastQuarter,
  currentYear,
  last12Months,
  allTime,
}

/// An inclusive local date range; a null bound is open.
typedef AiDateRange = ({DateTime? from, DateTime? to});

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The dates [p] stands for, relative to [today].
AiDateRange aiQuickRange(AiQuickPeriod p, DateTime today) {
  final t = _day(today);
  switch (p) {
    case AiQuickPeriod.last30Days:
      return (from: t.subtract(const Duration(days: 29)), to: t);
    case AiQuickPeriod.currentMonth:
      return (from: DateTime(t.year, t.month), to: t);
    case AiQuickPeriod.lastMonth:
      return (
        from: DateTime(t.year, t.month - 1),
        to: DateTime(t.year, t.month, 0),
      );
    case AiQuickPeriod.lastQuarter:
      final quarterStartMonth = ((t.month - 1) ~/ 3) * 3 + 1;
      return (
        from: DateTime(t.year, quarterStartMonth - 3),
        to: DateTime(t.year, quarterStartMonth, 0),
      );
    case AiQuickPeriod.currentYear:
      return (from: DateTime(t.year), to: t);
    case AiQuickPeriod.last12Months:
      return (from: DateTime(t.year - 1, t.month, t.day + 1), to: t);
    case AiQuickPeriod.allTime:
      return (from: null, to: null);
  }
}

/// The shortcut whose dates equal [range], if any (to highlight it).
AiQuickPeriod? aiMatchQuick(AiDateRange range, DateTime today) {
  for (final p in AiQuickPeriod.values) {
    final q = aiQuickRange(p, today);
    if (q.from == range.from && q.to == range.to) return p;
  }
  return null;
}

/// Request fields for [range]: no bounds is the whole history, otherwise
/// a custom period with whichever bounds are set.
({String preset, DateTime? from, DateTime? to}) aiPeriodFields(
  AiDateRange range,
) => range.from == null && range.to == null
    ? (preset: 'all_time', from: null, to: null)
    : (preset: 'custom', from: range.from, to: range.to);

/// The setup screen's starting dates for what the Reports screen shows.
AiDateRange aiRangeFromReport(
  ReportPeriodSelection s,
  DateTime today,
) => switch (s.preset) {
  ReportPreset.last30Days => aiQuickRange(AiQuickPeriod.last30Days, today),
  ReportPreset.last12Months => aiQuickRange(AiQuickPeriod.last12Months, today),
  ReportPreset.currentMonth => aiQuickRange(AiQuickPeriod.currentMonth, today),
  ReportPreset.currentYear => aiQuickRange(AiQuickPeriod.currentYear, today),
  ReportPreset.allTime => aiQuickRange(AiQuickPeriod.allTime, today),
  ReportPreset.custom => (
    from: s.customFrom == null ? null : _day(s.customFrom!),
    to: s.customTo == null ? null : _day(s.customTo!),
  ),
};

/// What another screen asks the setup screen to start from.
class AiSetupPrefill {
  const AiSetupPrefill({
    required this.range,
    this.walletIds = const [],
    this.filters,
    this.fromHistory = false,
  });

  final AiDateRange range;
  final List<String> walletIds;
  final AiAnalysisFilters? filters;

  /// Started from Cronologia: the screen shows where the filters came from.
  final bool fromHistory;
}

/// Why a Cronologia filter can't become an analysis.
enum AiHistoryPrefillProblem { adjustmentsOnly, transfersOnly }

/// Maps the Cronologia filters to an analysis scope. Cronologia's "to"
/// bound is exclusive (the start of the next day); the analysis takes
/// inclusive dates. Returns a problem for type filters the analysis
/// can't honour: it only looks at income and expenses.
({AiSetupPrefill? prefill, AiHistoryPrefillProblem? problem})
aiPrefillFromHistory(TransactionListFilter f) {
  switch (f.type) {
    case TransactionTypeFilter.adjustments:
      return (prefill: null, problem: AiHistoryPrefillProblem.adjustmentsOnly);
    case TransactionTypeFilter.transfers:
      return (prefill: null, problem: AiHistoryPrefillProblem.transfersOnly);
    case TransactionTypeFilter.all:
    case TransactionTypeFilter.debit:
    case TransactionTypeFilter.credit:
      break;
  }
  final from = f.occurredFrom == null ? null : _day(f.occurredFrom!.toLocal());
  final to = f.occurredTo == null
      ? null
      : _day(f.occurredTo!.toLocal().subtract(const Duration(days: 1)));
  final title = f.title?.trim();
  return (
    prefill: AiSetupPrefill(
      range: (from: from, to: to),
      walletIds: [?f.walletId],
      fromHistory: true,
      filters: AiAnalysisFilters(
        direction: switch (f.type) {
          TransactionTypeFilter.debit => 'DEBIT',
          TransactionTypeFilter.credit => 'CREDIT',
          _ => null,
        },
        categoryId: f.categoryId,
        title: title == null || title.isEmpty ? null : title,
        amountMinMinor: f.amountMinMinor,
        amountMaxMinor: f.amountMaxMinor,
      ),
    ),
    problem: null,
  );
}

/// Hands a prefill to the setup screen, which takes it once.
class AiSetupPrefillController extends Notifier<AiSetupPrefill?> {
  @override
  AiSetupPrefill? build() => null;

  void set(AiSetupPrefill prefill) => state = prefill;

  /// Called once the setup screen has read the prefill, after its first
  /// frame (providers can't change while widgets build).
  void clear() => state = null;
}

final aiSetupPrefillProvider =
    NotifierProvider<AiSetupPrefillController, AiSetupPrefill?>(
      AiSetupPrefillController.new,
    );
