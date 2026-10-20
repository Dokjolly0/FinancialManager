import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../ai/data/providers.dart';

/// The way into the AI analysis from Reports (plan.md section 32.7).
/// Hidden when the server does not offer the feature or settings can't
/// be loaded; points to setup until a provider is configured.
class AiAnalysisEntryCard extends ConsumerWidget {
  const AiAnalysisEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(aiSettingsProvider).value;
    if (settings == null || !settings.available) return const SizedBox.shrink();
    final ready = settings.setup.providerReady;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.aiReportsCardTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(ready ? l10n.aiReportsCardBody : l10n.aiReportsCardSetupBody),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => context.push(
                    ready ? AppRoutes.aiNew : AppRoutes.aiAssistant,
                  ),
                  icon: Icon(
                    ready ? Icons.play_arrow : Icons.settings_outlined,
                  ),
                  label: Text(
                    ready ? l10n.aiReportsCardStart : l10n.aiGoToSetup,
                  ),
                ),
                if (settings.setup.hasAnalyses)
                  OutlinedButton(
                    onPressed: () => context.push(AppRoutes.aiHistory),
                    child: Text(l10n.aiHistoryTitle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
