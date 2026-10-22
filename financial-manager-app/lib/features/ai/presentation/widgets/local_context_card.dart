import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/device_capabilities.dart';
import '../view_models/local_run_plan.dart';
import 'local_model_labels.dart';

/// A quick fix offered when the prompt fills the context.
class LocalContextFix {
  const LocalContextFix(this.label, this.onApply);

  final String label;
  final VoidCallback onApply;
}

/// "12 s", "3 min".
String formatLocalDuration(Duration d) => d.inSeconds < 90
    ? '${d.inSeconds.clamp(1, 89)} s'
    : '${(d.inSeconds / 60).round()} min';

/// The on-device part of the preview: where it runs, how full the context
/// is (green, amber above 85%, red when it doesn't fit), how long it should
/// take and what to watch out for.
class LocalContextCard extends StatelessWidget {
  const LocalContextCard({
    super.key,
    required this.plan,
    required this.usage,
    required this.estimate,
    required this.warnings,
    this.warmingUp = false,
    this.warmUpError,
    this.fixes = const [],
  });

  final LocalRunPlan plan;
  final LocalContextUsage usage;
  final LocalTimeEstimate estimate;
  final Set<LocalRunWarning> warnings;

  /// The model is loading to count the prompt exactly.
  final bool warmingUp;
  final String? warmUpError;
  final List<LocalContextFix> fixes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final color = switch (usage.level) {
      LocalContextLevel.ok => Colors.green.shade600,
      LocalContextLevel.tight => Colors.amber.shade700,
      LocalContextLevel.overflow => theme.colorScheme.error,
    };
    final warningTexts = [
      if (warnings.contains(LocalRunWarning.warm)) l10n.aiLocalWarnWarm,
      if (warnings.contains(LocalRunWarning.lowBattery))
        l10n.aiLocalWarnBattery,
      if (warnings.contains(LocalRunWarning.lowMemory)) l10n.aiLocalWarnMemory,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localRuntimeSummary(l10n, plan.record, plan.params),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.aiLocalContextUse(
                      numbers.format(usage.usedTokens),
                      numbers.format(usage.contextTokens),
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (warmingUp)
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey('local-context-bar'),
                minHeight: 8,
                value: usage.share.clamp(0.0, 1.0),
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                l10n.aiLocalContextParts(
                  numbers.format(usage.inputTokens),
                  numbers.format(usage.reservedOutputTokens),
                ),
                usage.exact
                    ? l10n.aiLocalCountExact
                    : l10n.aiLocalCountEstimated,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (usage.level != LocalContextLevel.ok) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                usage.level == LocalContextLevel.overflow
                    ? l10n.aiLocalContextOverflow
                    : l10n.aiLocalContextTight,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
            if (fixes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final f in fixes)
                    ActionChip(label: Text(f.label), onPressed: f.onApply),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.aiLocalTimeEstimate(
                      formatLocalDuration(estimate.low),
                      formatLocalDuration(estimate.high),
                    ),
                  ),
                ),
              ],
            ),
            if (plan.speedSource == LocalSpeedSource.fallback)
              Text(l10n.aiLocalTimeRough, style: theme.textTheme.bodySmall),
            if (warmUpError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                warmUpError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            for (final w in warningTexts) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(w, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
