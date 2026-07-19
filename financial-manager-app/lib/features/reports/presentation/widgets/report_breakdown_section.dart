import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/report_breakdown.dart';
import '../state/report_state.dart';

/// Ripartizione (plan.md section 7.12, 18.4, 18.5): two tabs (titolo/
/// modello, categoria); within each, uscite and entrate use separate
/// denominators and are never mixed into one chart (section 18.4).
class ReportBreakdownSection extends StatefulWidget {
  const ReportBreakdownSection({
    super.key,
    required this.breakdown,
    required this.groupBy,
    required this.isLoading,
    required this.onGroupByChanged,
  });

  final ReportBreakdown? breakdown;
  final String groupBy;
  final bool isLoading;
  final ValueChanged<String> onGroupByChanged;

  @override
  State<ReportBreakdownSection> createState() => _ReportBreakdownSectionState();
}

class _ReportBreakdownSectionState extends State<ReportBreakdownSection> {
  bool _showDebits = true;

  @override
  Widget build(BuildContext context) {
    final items = widget.breakdown == null
        ? const <BreakdownItem>[]
        : (_showDebits ? widget.breakdown!.debits : widget.breakdown!.credits);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportBreakdownTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: ReportGroupBy.title,
                  label: Text(l10n.groupByTitleOption),
                ),
                ButtonSegment(
                  value: ReportGroupBy.category,
                  label: Text(l10n.groupByCategoryOption),
                ),
              ],
              selected: {widget.groupBy},
              onSelectionChanged: (s) => widget.onGroupByChanged(s.first),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.debitsColumnLabel)),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.creditsColumnLabel),
                ),
              ],
              selected: {_showDebits},
              onSelectionChanged: (s) => setState(() => _showDebits = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(l10n.noTransactionsForView),
              )
            else
              Column(
                children: [for (final item in items) _BreakdownRow(item: item)],
              ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});

  final BreakdownItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${item.amount.format()} · ${item.percentage.toStringAsFixed(1)}%',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item.percentage / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: item.isOther ? colorScheme.outline : colorScheme.primary,
            ),
          ),
          Text(
            AppLocalizations.of(
              context,
            ).transactionCountLabel(item.transactionCount),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
