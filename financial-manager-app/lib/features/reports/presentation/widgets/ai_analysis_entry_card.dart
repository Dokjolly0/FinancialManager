import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../account/presentation/view_models/account_providers.dart';
import '../../../ai/data/providers.dart';
import '../../../ai/domain/models/ai_settings.dart';

/// The way into the AI analysis from Reports (plan.md section 32.7).
/// Hidden when the AI features are off (section 32.10), the server offers
/// neither path or settings can't be loaded; points to setup until a
/// provider is configured, unless analyses run on the phone (the setup
/// screen then says what is missing).
class AiAnalysisEntryCard extends ConsumerWidget {
  const AiAnalysisEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (!ref.watch(aiFeaturesEnabledProvider)) return const SizedBox.shrink();
    final settings = ref.watch(aiSettingsProvider).value;
    if (settings == null || !settings.anyAvailable) {
      return const SizedBox.shrink();
    }
    final ready =
        (settings.available && settings.setup.providerReady) ||
        (settings.onDeviceAvailable && settings.mode == AiMode.onDevice);

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
              runSpacing: AppSpacing.xs,
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
                if (ready)
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.aiChat),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(l10n.aiChatTitle),
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
