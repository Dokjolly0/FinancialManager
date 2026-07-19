import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../view_models/report_controller.dart';
import '../widgets/monthly_comparison_section.dart';
import '../widgets/period_selector.dart';
import '../widgets/report_breakdown_section.dart';
import '../widgets/report_summary_card.dart';
import '../widgets/report_trend_chart.dart';

/// Report (plan.md section 7.12): period header, riepilogo, andamento,
/// ripartizione, confronto mensile (only when the period spans more than
/// one calendar month — section 18.8).
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportControllerProvider);
    final controller = ref.read(reportControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          PeriodSelector(
            selection: state.period,
            onPresetSelected: controller.setPreset,
            onCustomRangeSelected: controller.setCustomRange,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Includi rettifiche',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: state.includeAdjustments,
                  onChanged: controller.toggleIncludeAdjustments,
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading && !state.hasData
                ? const SkeletonList()
                : state.error != null && !state.hasData
                ? InlineError(message: state.error!, onRetry: controller.refresh)
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      children: [
                        if (state.summary != null)
                          ReportSummaryCard(summary: state.summary!),
                        const SizedBox(height: AppSpacing.md),
                        if (state.timeseries != null)
                          ReportTrendChart(timeseries: state.timeseries!),
                        const SizedBox(height: AppSpacing.md),
                        ReportBreakdownSection(
                          breakdown: state.breakdown,
                          groupBy: state.groupBy,
                          isLoading: state.isBreakdownLoading,
                          onGroupByChanged: controller.setGroupBy,
                        ),
                        if (state.monthlyComparison != null &&
                            state.monthlyComparison!.spansMultipleMonths) ...[
                          const SizedBox(height: AppSpacing.md),
                          MonthlyComparisonSection(
                            comparison: state.monthlyComparison!,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
