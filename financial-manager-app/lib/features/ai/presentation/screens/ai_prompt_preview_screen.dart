import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../view_models/ai_draft_controller.dart';
import '../widgets/ai_provider_labels.dart';
import 'ai_analysis_setup_screen.dart';

/// The exact prompt before sending (plan.md section 32.6): a summary of
/// what leaves the server, the editable instructions, and the read-only
/// rules and data.
class AiPromptPreviewScreen extends ConsumerStatefulWidget {
  const AiPromptPreviewScreen({super.key});

  @override
  ConsumerState<AiPromptPreviewScreen> createState() =>
      _AiPromptPreviewScreenState();
}

class _AiPromptPreviewScreenState extends ConsumerState<AiPromptPreviewScreen> {
  late final TextEditingController _instructions;

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(
      text: ref.read(aiDraftControllerProvider).preview?.instructions ?? '',
    );
  }

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  void _send() {
    final l10n = AppLocalizations.of(context);
    if (_instructions.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.aiInstructionsRequired)));
      return;
    }
    ref
        .read(aiDraftControllerProvider.notifier)
        .setInstructions(_instructions.text.trim());
    context.pushReplacement(AppRoutes.aiRun);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = ref.watch(aiDraftControllerProvider);
    final preview = draft.preview;

    if (preview == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.aiPreviewTitle)),
        body: Center(
          child: Text(
            draft.error == null
                ? l10n.aiPreviewMissing
                : presentError(draft.error!, l10n).message,
          ),
        ),
      );
    }

    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final d = preview.disclosure;
    final cost = preview.estimatedMaxCost;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiPreviewSentTo(
                      aiProviderLabel(l10n, preview.provider),
                      preview.model,
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Fact(
                    icon: Icons.account_balance_wallet_outlined,
                    text: l10n.aiPreviewWallets(d.walletCount),
                  ),
                  _Fact(
                    icon: Icons.table_chart_outlined,
                    text: d.sections.isEmpty
                        ? l10n.aiPreviewOnlyTotals
                        : l10n.aiPreviewSections(
                            d.sections
                                .map((s) => aiSectionLabel(l10n, s))
                                .join(', '),
                          ),
                  ),
                  _Fact(
                    icon: Icons.receipt_long_outlined,
                    text: d.transactionCount == 0
                        ? l10n.aiPreviewNoTransactions
                        : l10n.aiPreviewTransactions(
                            d.transactionCount,
                            d.transactionsOmitted,
                          ),
                  ),
                  if (d.anonymized)
                    _Fact(
                      icon: Icons.visibility_off_outlined,
                      text: l10n.aiPreviewAnonymized,
                    ),
                  if (d.includesPersonalContext)
                    _Fact(
                      icon: Icons.person_outline,
                      text: l10n.aiPreviewWithContext,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.token_outlined, size: 18),
                        label: Text(
                          l10n.aiPreviewTokens(
                            numbers.format(preview.estimatedInputTokens),
                          ),
                        ),
                      ),
                      if (cost != null)
                        Chip(
                          avatar: const Icon(Icons.payments_outlined, size: 18),
                          label: Text(
                            l10n.aiPreviewCost(
                              cost.toStringAsFixed(cost < 0.1 ? 4 : 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.aiInstructionsLabel, style: theme.textTheme.titleMedium),
          Text(l10n.aiInstructionsHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _instructions,
            minLines: 4,
            maxLines: 12,
            maxLength: aiInstructionsMaxLength,
            textCapitalization: TextCapitalization.sentences,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _instructions.text = preview.instructions),
              icon: const Icon(Icons.restart_alt),
              label: Text(l10n.aiRestoreInstructions),
            ),
          ),
          _ReadOnlyBlock(
            title: l10n.aiSystemPromptLabel,
            subtitle: l10n.aiSystemPromptHint,
            text: preview.systemPrompt,
          ),
          _ReadOnlyBlock(
            title: l10n.aiDataBlockLabel,
            subtitle: l10n.aiDataBlockHint,
            text: preview.dataBlock,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: draft.isLoading ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(l10n.aiSendAction),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// A collapsible, selectable, monospace block that cannot be edited.
class _ReadOnlyBlock extends StatelessWidget {
  const _ReadOnlyBlock({
    required this.title,
    required this.subtitle,
    required this.text,
  });

  final String title;
  final String subtitle;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

/// Helper used by the analysis screen to show what was sent.
void showAiSentDataSheet(BuildContext context, AiAnalysisDetail detail) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Text(
            l10n.aiDataSentTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ReadOnlyBlock(
            title: l10n.aiSystemPromptLabel,
            subtitle: l10n.aiSystemPromptHint,
            text: detail.systemPrompt,
          ),
          _ReadOnlyBlock(
            title: l10n.aiDataBlockLabel,
            subtitle: l10n.aiDataSentHint,
            text: detail.contextMessage?.content ?? '',
          ),
        ],
      ),
    ),
  );
}
