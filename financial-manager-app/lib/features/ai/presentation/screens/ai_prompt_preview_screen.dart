import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/local/local_llm_engine.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/device_capabilities.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_record.dart';
import '../view_models/ai_draft_controller.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/ai_provider_labels.dart';
import '../widgets/local_context_card.dart';
import 'ai_analysis_setup_screen.dart';

/// The exact prompt before sending (plan.md section 32.6): a summary of
/// what leaves the server, the editable instructions, and the read-only
/// rules and data. On the phone (plan.md section 33) it also shows how much
/// of the model's context the run takes and how long it should last; the
/// model loads while the user reads, so the estimate becomes an exact
/// count.
class AiPromptPreviewScreen extends ConsumerStatefulWidget {
  const AiPromptPreviewScreen({super.key});

  @override
  ConsumerState<AiPromptPreviewScreen> createState() =>
      _AiPromptPreviewScreenState();
}

class _AiPromptPreviewScreenState extends ConsumerState<AiPromptPreviewScreen> {
  late final TextEditingController _instructions;

  /// The engine's count of the prompt with fingerprint [_counted].
  int? _exactTokens;
  String? _counted;
  bool _warmingUp = false;
  bool _modelLoaded = false;
  String? _warmUpError;
  Set<LocalRunWarning> _warnings = const {};

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(
      text: ref.read(aiDraftControllerProvider).preview?.instructions ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
  }

  /// Loads the model and counts the prompt with its tokenizer.
  Future<void> _warmUp() async {
    final preview = ref.read(aiDraftControllerProvider).preview;
    if (!mounted ||
        preview == null ||
        preview.target != AiMode.onDevice ||
        !ref.read(localAiSupportedProvider) ||
        _counted == preview.dataFingerprint) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _warmingUp = true;
      _warmUpError = null;
      _exactTokens = null;
    });
    try {
      final caps = await ref.read(deviceCapabilitiesSourceProvider).read();
      if (mounted) setState(() => _warnings = runWarnings(caps));
      final session = await ref.read(localModelHostProvider).acquire();
      final count = await session.engine.countTokens(
        '${preview.systemPrompt}\n\n${preview.instructions}\n\n${preview.dataBlock}',
      );
      if (!mounted) return;
      setState(() {
        _modelLoaded = true;
        _exactTokens = count;
        _counted = preview.dataFingerprint;
      });
    } on LocalEngineException catch (e) {
      if (mounted) {
        setState(() => _warmUpError = localizeErrorCode(l10n, e.code));
      }
    } catch (_) {
      // The estimate stays; the run reports any real problem.
    } finally {
      if (mounted) setState(() => _warmingUp = false);
    }
  }

  Future<void> _repreview(AiAnalysisRequest request) =>
      ref.read(aiDraftControllerProvider.notifier).preview(request);

  /// Re-previews with the budget and limits of the plan now saved.
  Future<void> _replan(AiAnalysisRequest request) async {
    ref.invalidate(localRunPlanProvider);
    final plan = await ref.read(localRunPlanProvider.future);
    if (plan == null || !mounted) return;
    await _repreview(
      request.copyWith(budgetTokens: plan.budgetTokens, device: plan.device),
    );
  }

  Future<void> _shorterAnswer(
    LocalRunPlan plan,
    AiAnalysisRequest request,
  ) async {
    final store = ref.read(modelStoreProvider);
    final choice = await store.runtimeChoice(plan.record.id);
    await store.setRuntimeChoice(
      plan.record.id,
      LocalRuntimeChoice(
        backend: choice?.backend ?? plan.params.backend,
        contextTokens: choice?.contextTokens ?? plan.params.contextTokens,
        temperature: choice?.temperature,
        maxOutputTokens: math.max(256, plan.params.maxOutputTokens ~/ 2),
      ),
    );
    await _replan(request);
  }

  List<LocalContextFix> _fixes(
    AppLocalizations l10n,
    LocalRunPlan plan,
    LocalContextUsage usage,
    AiAnalysisRequest request,
  ) {
    if (usage.level == LocalContextLevel.ok) return const [];
    final r = plan.record;
    final maxContext = plan.params.backend == LocalBackend.cpu
        ? (r.maxContextTokensCpu ?? r.maxContextTokens)
        : r.maxContextTokens;
    return [
      if (request.profile != 'compact')
        LocalContextFix(
          l10n.aiLocalFixCompact,
          () => _repreview(
            request.copyWith(
              profile: 'compact',
              maxTransactions: math.min(
                request.maxTransactions,
                aiCompactDefaultTransactions,
              ),
            ),
          ),
        ),
      if (request.includeTransactions && request.maxTransactions > 10)
        LocalContextFix(
          l10n.aiLocalFixFewerTransactions,
          () => _repreview(
            request.copyWith(
              maxTransactions: math.max(10, request.maxTransactions ~/ 2),
            ),
          ),
        ),
      if (plan.params.maxOutputTokens > 512)
        LocalContextFix(
          l10n.aiLocalFixShorterAnswer,
          () => _shorterAnswer(plan, request),
        ),
      if (plan.params.contextTokens < maxContext)
        LocalContextFix(l10n.aiLocalFixLargerContext, () async {
          await context.push(AppRoutes.aiLocalRuntime);
          if (mounted) await _replan(request);
        }),
    ];
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
    // A quick fix re-previews: count the new prompt.
    ref.listen(
      aiDraftControllerProvider.select((d) => d.preview?.dataFingerprint),
      (_, _) => _warmUp(),
    );

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
    final onDevice = preview.target == AiMode.onDevice;
    final plan = onDevice ? ref.watch(localRunPlanProvider).value : null;
    final usage = plan?.usage(
      estimatedInputTokens: preview.estimatedInputTokens,
      exactInputTokens: _counted == preview.dataFingerprint
          ? _exactTokens
          : null,
    );
    final overflow = usage?.level == LocalContextLevel.overflow;

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
                    onDevice
                        ? l10n.aiPreviewOnDevice(
                            plan?.record.label ?? preview.model,
                          )
                        : l10n.aiPreviewSentTo(
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
                      if (onDevice)
                        Chip(
                          avatar: const Icon(Icons.money_off, size: 18),
                          label: Text(l10n.aiPreviewNoCost),
                        )
                      else
                        Chip(
                          avatar: const Icon(Icons.token_outlined, size: 18),
                          label: Text(
                            l10n.aiPreviewTokens(
                              numbers.format(preview.estimatedInputTokens),
                            ),
                          ),
                        ),
                      if (d.profile == 'compact')
                        Chip(
                          avatar: const Icon(Icons.compress, size: 18),
                          label: Text(l10n.aiCompactProfile),
                        ),
                      if (!onDevice && cost != null)
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
          if (d.compactionSteps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.aiPreviewCompacted(d.compactionSteps.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (plan != null && usage != null && draft.request != null) ...[
            const SizedBox(height: AppSpacing.md),
            LocalContextCard(
              plan: plan,
              usage: usage,
              estimate: plan.estimate(
                inputTokens: usage.inputTokens,
                loaded: _modelLoaded,
              ),
              warnings: _warnings,
              warmingUp: _warmingUp,
              warmUpError: _warmUpError,
              fixes: _fixes(l10n, plan, usage, draft.request!),
            ),
          ],
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
            onPressed: draft.isLoading || overflow ? null : _send,
            icon: Icon(onDevice ? Icons.play_arrow : Icons.send),
            label: Text(
              onDevice ? l10n.aiRunOnDeviceAction : l10n.aiSendAction,
            ),
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
