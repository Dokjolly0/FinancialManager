import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/current_user_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../view_models/ai_draft_controller.dart';
import '../view_models/ai_run_choice.dart';
import '../view_models/local_models_controller.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/ai_consent_sheet.dart';
import '../widgets/ai_provider_labels.dart';

/// "Chiedi all'assistente" (plan.md section 34): a question about the
/// user's own transactions, answered as a chat. There is no setup: the
/// server picks the data (the whole history and its transaction list),
/// the preview only gives the fingerprint and, on the phone, the budget.
/// Sending opens the conversation on the run screen.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _question = TextEditingController();

  /// The picked [AiRunChoice.key]; null starts on the default model.
  String? _choiceKey;

  /// The draft is shared with the report setup: only its errors after a
  /// send from here are shown.
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _selectChoice(AiRunChoice choice) {
    setState(() => _choiceKey = choice.key);
    if (choice is AiLocalChoice &&
        ref.read(localModelsControllerProvider).activeModelId !=
            choice.record.id) {
      ref
          .read(localModelsControllerProvider.notifier)
          .setActive(choice.record.id);
    }
  }

  Future<void> _send(
    AiSettings settings,
    AiRunChoice choice,
    LocalRunPlan? plan,
  ) async {
    final question = _question.text.trim();
    if (question.isEmpty) return;
    final onDevice = choice is AiLocalChoice && plan != null;
    final consent = onDevice
        ? (settings.localConsent ?? settings.consent)
        : settings.consent;
    if (consent.required) {
      final accepted = await AiConsentSheet.show(
        context,
        consentVersion: consent.currentVersion,
        mode: onDevice ? AiMode.onDevice : AiMode.cloud,
      );
      if (!accepted) return;
    }
    setState(() => _sent = true);
    final request = AiAnalysisRequest.chat(
      question,
      profile: onDevice ? 'compact' : null,
      budgetTokens: onDevice ? plan.budgetTokens : null,
      device: onDevice ? plan.device : null,
      target: onDevice ? AiMode.onDevice.wire : AiMode.cloud.wire,
      credentialId: choice is AiCloudChoice ? choice.credential.id : null,
    );
    final ok = await ref
        .read(aiDraftControllerProvider.notifier)
        .preview(request);
    if (!ok) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      unawaited(
        ref
            .read(aiLastChoiceStoreProvider)
            .write(userId, choice.key)
            .catchError((_) {}),
      );
    }
    if (mounted) context.pushReplacement(AppRoutes.aiRun);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(aiSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiChatTitle),
        actions: [
          IconButton(
            tooltip: l10n.aiHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.aiHistory),
          ),
        ],
      ),
      body: switch (settingsAsync) {
        AsyncData(value: final settings) => _body(context, settings),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: error is AppError
                ? presentError(error, l10n).message
                : l10n.errorCodeUnknownError,
            onRetry: () => ref.invalidate(aiSettingsProvider),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, AiSettings settings) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supported = ref.watch(localAiSupportedProvider);
    final models = settings.onDeviceAvailable && supported
        ? ref.watch(localModelsControllerProvider)
        : null;
    final lastAsync = ref.watch(aiLastChoiceProvider);
    if ((models != null && models.isLoading) || lastAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final choices = aiRunChoices(
      settings,
      localSupported: supported,
      installed: models?.installed ?? const [],
    );
    final choice =
        choices.where((c) => c.key == _choiceKey).firstOrNull ??
        defaultAiRunChoice(
          choices,
          settings,
          activeLocalModelId: models?.activeModelId,
          lastKey: lastAsync.value,
        );
    if (choice == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.aiNotReadyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            settings.available ? l10n.aiNotReadyBody : l10n.aiUnavailableBody,
          ),
          const SizedBox(height: AppSpacing.md),
          if (settings.anyAvailable)
            FilledButton(
              onPressed: () => context.push(AppRoutes.aiAssistant),
              child: Text(l10n.aiGoToSetup),
            ),
        ],
      );
    }
    LocalRunPlan? plan;
    if (choice is AiLocalChoice) {
      if (models?.activeModelId != choice.record.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref
                .read(localModelsControllerProvider.notifier)
                .setActive(choice.record.id);
          }
        });
      }
      plan = ref.watch(localRunPlanProvider).value;
      if (plan == null || plan.record.id != choice.record.id) {
        return const Center(child: CircularProgressIndicator());
      }
    }
    final draft = ref.watch(aiDraftControllerProvider);
    final canSend = _question.text.trim().isNotEmpty && !draft.isLoading;
    final examples = [
      l10n.aiChatExampleInsurance,
      l10n.aiChatExampleFuel,
      l10n.aiChatExampleYearly,
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(l10n.aiChatIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.aiChatExamplesTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final e in examples)
                    ActionChip(
                      label: Text(e),
                      onPressed: () => _question.text = e,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                key: ValueKey('chat-model-${choice.key}'),
                initialValue: choice.key,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.aiRunModelLabel,
                  prefixIcon: Icon(
                    choice.isOnDevice
                        ? Icons.smartphone_outlined
                        : Icons.cloud_outlined,
                  ),
                ),
                items: [
                  for (final c in choices)
                    DropdownMenuItem(
                      value: c.key,
                      child: Text(switch (c) {
                        AiCloudChoice(:final credential) =>
                          '${aiProviderLabel(l10n, credential.provider)} · ${credential.model}',
                        AiLocalChoice(:final record) =>
                          '${l10n.aiModeOnDevice} · ${record.label}',
                      }, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (key) {
                  for (final c in choices) {
                    if (c.key == key) _selectChoice(c);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                choice.isOnDevice
                    ? l10n.aiChatDataNoteOnDevice
                    : l10n.aiChatDataNoteCloud,
                style: theme.textTheme.bodySmall,
              ),
              if (_sent && draft.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineError(message: presentError(draft.error!, l10n).message),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-question'),
                    controller: _question,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: aiChatQuestionMaxLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: l10n.aiChatHint,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: canSend
                        ? (_) => _send(settings, choice, plan)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                draft.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filled(
                        tooltip: l10n.aiAskAction,
                        icon: const Icon(Icons.send),
                        onPressed: canSend
                            ? () => _send(settings, choice, plan)
                            : null,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
