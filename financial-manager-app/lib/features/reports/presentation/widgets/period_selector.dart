import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/first_day_of_week_scope.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../domain/models/report_period.dart';

/// Header periodo (plan.md section 7.12): preset chips plus a custom date
/// range picker. Selecting "Personalizzato" immediately opens the range
/// picker rather than leaving an ambiguous half-selected state.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({
    super.key,
    required this.selection,
    required this.onPresetSelected,
    required this.onCustomRangeSelected,
  });

  final ReportPeriodSelection selection;
  final ValueChanged<ReportPreset> onPresetSelected;
  final void Function(DateTime from, DateTime to) onCustomRangeSelected;

  Future<void> _pickCustomRange(
    BuildContext context,
    String firstDayOfWeek,
  ) async {
    final now = DateTime.now();
    final initial = selection.customFrom != null && selection.customTo != null
        ? DateTimeRange(start: selection.customFrom!, end: selection.customTo!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: initial,
      builder: (context, child) =>
          firstDayOfWeekScope(context, child, firstDayOfWeek),
    );
    if (picked != null) {
      onCustomRangeSelected(picked.start, picked.end);
    }
  }

  String _chipLabel(ReportPreset preset) {
    if (preset != ReportPreset.custom) return preset.label;
    if (selection.preset != ReportPreset.custom ||
        selection.customFrom == null ||
        selection.customTo == null) {
      return preset.label;
    }
    final format = DateFormat('d MMM', 'it_IT');
    return '${format.format(selection.customFrom!)} - ${format.format(selection.customTo!)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstDayOfWeek =
        ref.watch(accountProfileProvider).value?.firstDayOfWeek ?? 'monday';

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: ReportPreset.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final preset = ReportPreset.values[index];
          final selected = selection.preset == preset;
          return ChoiceChip(
            label: Text(_chipLabel(preset)),
            selected: selected,
            onSelected: (_) {
              if (preset == ReportPreset.custom) {
                _pickCustomRange(context, firstDayOfWeek);
              } else {
                onPresetSelected(preset);
              }
            },
          );
        },
      ),
    );
  }
}
