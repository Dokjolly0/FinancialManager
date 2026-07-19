import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/report_summary.dart';

/// Sezione riepilogo (plan.md section 7.12): saldo iniziale/finale, totali
/// ordinari, risultato netto, numero operazioni, tasso di risparmio.
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({super.key, required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Saldo iniziale',
                    value: summary.openingBalance.format(),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Saldo finale',
                    value: summary.closingBalance.format(),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Entrate',
                    value: summary.totalCredits.format(),
                    valueColor: colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Uscite',
                    value: summary.totalDebits.format(),
                    valueColor: colorScheme.error,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Metric(label: 'Risultato netto', value: summary.net.format()),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${summary.transactionCount} operazioni',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (summary.savingsRatePercent != null)
                  Text(
                    'Risparmio: ${summary.savingsRatePercent!.toStringAsFixed(1)}%',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
