import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/session/current_user_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/formatting/money.dart';
import '../../../categories/data/providers.dart';
import '../../../reports/presentation/view_models/report_controller.dart';
import '../../../wallets/data/providers.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../view_models/ai_draft_controller.dart';
import '../view_models/ai_period.dart';
import '../view_models/ai_run_choice.dart';
import '../view_models/local_models_controller.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/ai_consent_sheet.dart';
import '../widgets/ai_provider_labels.dart';

String aiSectionLabel(AppLocalizations l10n, AiDataSection s) => switch (s) {
  AiDataSection.monthly => l10n.aiSectionMonthly,
  AiDataSection.categories => l10n.aiSectionCategories,
  AiDataSection.titles => l10n.aiSectionTitles,
  AiDataSection.transfers => l10n.aiSectionTransfers,
  AiDataSection.recurring => l10n.aiSectionRecurring,
  AiDataSection.personalContext => l10n.aiSectionPersonalContext,
};

String aiQuickPeriodLabel(AppLocalizations l10n, AiQuickPeriod p) =>
    switch (p) {
      AiQuickPeriod.last30Days => l10n.aiPeriodLast30Days,
      AiQuickPeriod.currentMonth => l10n.aiPeriodCurrentMonth,
      AiQuickPeriod.lastMonth => l10n.aiPeriodLastMonth,
      AiQuickPeriod.lastQuarter => l10n.aiPeriodLastQuarter,
      AiQuickPeriod.currentYear => l10n.aiPeriodCurrentYear,
      AiQuickPeriod.last12Months => l10n.aiPeriodLast12Months,
      AiQuickPeriod.allTime => l10n.aiPeriodAllTime,
    };

/// Reports → Analisi AI (plan.md section 32.7): choose what to analyze and
/// what data to send, then open the preview. Any configured model can run
/// it: every cloud account with a model and every model installed on the
/// phone. On the phone (plan.md section 33) the compact profile is on by
/// default and the prompt is held to what fits the model's context.
class AiAnalysisSetupScreen extends ConsumerStatefulWidget {
  const AiAnalysisSetupScreen({super.key});

  @override
  ConsumerState<AiAnalysisSetupScreen> createState() =>
      _AiAnalysisSetupScreenState();
}

class _AiAnalysisSetupScreenState extends ConsumerState<AiAnalysisSetupScreen> {
  AiPreset? _preset;

  /// Inclusive local dates; a null bound is open, both null is the whole
  /// history.
  late AiDateRange _range;
  final Set<String> _walletIds = {};

  /// Filters carried over from Cronologia; each can be removed.
  AiAnalysisFilters? _filters;
  bool _fromHistory = false;
  Set<AiDataSection> _sections = {};
  bool _includeTransactions = false;
  double _maxTransactions = aiDefaultMaxTransactions.toDouble();
  bool _anonymize = false;
  bool _includeAdjustments = false;

  /// The short prompt for small models; on by default on the phone.
  bool _compact = false;

  /// The picked [AiRunChoice.key]; null starts on the saved mode's model.
  String? _choiceKey;
  final _question = TextEditingController();
  bool _defaultsApplied = false;
  String? _questionError;

  @override
  void initState() {
    super.initState();
    // Start from what Cronologia asked for, else from what Reports shows.
    final prefill = ref.read(aiSetupPrefillProvider);
    if (prefill != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(aiSetupPrefillProvider.notifier).clear(),
      );
      _range = prefill.range;
      _walletIds.addAll(prefill.walletIds);
      _filters = prefill.filters == null || prefill.filters!.isEmpty
          ? null
          : prefill.filters;
      _fromHistory = prefill.fromHistory;
      return;
    }
    final report = ref.read(reportControllerProvider);
    _range = aiRangeFromReport(report.period, DateTime.now());
    if (report.walletId != null) _walletIds.add(report.walletId!);
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _selectPreset(AiPreset preset, {AiSettings? settings}) {
    setState(() {
      _preset = preset;
      _sections = {...preset.defaultSections};
      _includeTransactions =
          preset.defaultIncludeTransactions ||
          (settings?.defaultIncludeTransactions ?? false);
      _questionError = null;
    });
  }

  /// Picks one bound; a "from" after "to" (or the reverse) moves the
  /// other bound along so the range stays valid.
  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = isFrom ? _range.from : _range.to;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDate: current ?? (isFrom ? _range.to : null) ?? today,
    );
    if (picked == null) return;
    setState(() {
      var from = isFrom ? picked : _range.from;
      var to = isFrom ? _range.to : picked;
      if (from != null && to != null && from.isAfter(to)) {
        if (isFrom) {
          to = from;
        } else {
          from = to;
        }
      }
      _range = (from: from, to: to);
    });
  }

  AiRunChoice? _choiceFor(
    List<AiRunChoice> choices,
    AiSettings settings,
    String? activeLocalModelId,
    String? lastKey,
  ) {
    for (final c in choices) {
      if (c.key == _choiceKey) return c;
    }
    return defaultAiRunChoice(
      choices,
      settings,
      activeLocalModelId: activeLocalModelId,
      lastKey: lastKey,
    );
  }

  /// Moving between the phone and the cloud flips the compact profile to
  /// its default there. A phone model becomes the active one: that is the
  /// model the engine loads.
  void _selectChoice(AiRunChoice choice, AiRunChoice? previous) {
    setState(() => _choiceKey = choice.key);
    if (choice.isOnDevice != (previous?.isOnDevice ?? false)) {
      _setCompact(choice.isOnDevice);
    }
    if (choice is AiLocalChoice &&
        ref.read(localModelsControllerProvider).activeModelId !=
            choice.record.id) {
      ref
          .read(localModelsControllerProvider.notifier)
          .setActive(choice.record.id);
    }
  }

  String _choiceLabel(AppLocalizations l10n, AiRunChoice c) => switch (c) {
    AiCloudChoice(:final credential) =>
      '${aiProviderLabel(l10n, credential.provider)} · ${credential.model}',
    AiLocalChoice(:final record) => '${l10n.aiModeOnDevice} · ${record.label}',
  };

  void _setCompact(bool on) => setState(() {
    _compact = on;
    _maxTransactions =
        (on ? aiCompactDefaultTransactions : aiDefaultMaxTransactions)
            .toDouble();
  });

  Future<void> _preview(
    AiSettings settings,
    AiRunChoice choice,
    LocalRunPlan? plan,
  ) async {
    final l10n = AppLocalizations.of(context);
    final preset = _preset;
    if (preset == null) return;
    if (preset.isCustom && _question.text.trim().isEmpty) {
      setState(() => _questionError = l10n.errorCodeRequiredField);
      return;
    }
    final onDevice = choice is AiLocalChoice && plan != null;
    final consent = onDevice
        ? (settings.localConsent ?? settings.consent)
        : settings.consent;
    if (consent.required) {
      if (!mounted) return;
      final accepted = await AiConsentSheet.show(
        context,
        consentVersion: consent.currentVersion,
        mode: onDevice ? AiMode.onDevice : AiMode.cloud,
      );
      if (!accepted) return;
    }

    final request = AiAnalysisRequest(
      preset: preset.id,
      periodPreset: aiPeriodFields(_range).preset,
      customFrom: _range.from,
      customTo: _range.to,
      walletIds: _walletIds.toList(),
      filters: _filters,
      sections: _sections,
      includeTransactions: _includeTransactions,
      maxTransactions: _maxTransactions.round(),
      anonymizeTitles: _anonymize,
      includeAdjustments: _includeAdjustments,
      instructions: preset.isCustom ? _question.text.trim() : null,
      profile: _compact ? 'compact' : null,
      target: onDevice ? AiMode.onDevice.wire : AiMode.cloud.wire,
      credentialId: choice is AiCloudChoice ? choice.credential.id : null,
      budgetTokens: onDevice ? plan.budgetTokens : null,
      device: onDevice ? plan.device : null,
    );
    final ok = await ref
        .read(aiDraftControllerProvider.notifier)
        .preview(request);
    if (!ok) return;
    // Remembered once used, not when merely touched in the picker.
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      unawaited(
        ref
            .read(aiLastChoiceStoreProvider)
            .write(userId, choice.key)
            .catchError((_) {}),
      );
    }
    if (mounted) context.push(AppRoutes.aiPreview);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(aiSettingsProvider);
    final presetsAsync = ref.watch(aiPresetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiNewAnalysisTitle),
        actions: [
          IconButton(
            tooltip: l10n.aiHistoryTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.aiHistory),
          ),
        ],
      ),
      body: switch ((settingsAsync, presetsAsync)) {
        (AsyncData(value: final settings), AsyncData(value: final presets)) =>
          _body(context, settings, presets),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: error is AppError
                ? presentError(error, l10n).message
                : l10n.errorCodeUnknownError,
            onRetry: () {
              ref.invalidate(aiSettingsProvider);
              ref.invalidate(aiPresetsProvider);
            },
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(
    BuildContext context,
    AiSettings settings,
    List<AiPreset> presets,
  ) {
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
    final choice = _choiceFor(
      choices,
      settings,
      models?.activeModelId,
      lastAsync.value,
    );
    if (choice == null) {
      final localFirst =
          settings.onDeviceAvailable &&
          (settings.mode == AiMode.onDevice || !settings.available);
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.aiNotReadyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localFirst
                ? (supported
                      ? l10n.aiLocalNotReadyBody
                      : l10n.errorCodeAiLocalUnsupported)
                : settings.available
                ? l10n.aiNotReadyBody
                : l10n.aiUnavailableBody,
          ),
          const SizedBox(height: AppSpacing.md),
          if (localFirst && supported)
            FilledButton(
              onPressed: () => context.push(AppRoutes.aiLocalModels),
              child: Text(l10n.aiLocalChooseModel),
            )
          else if (settings.anyAvailable)
            FilledButton(
              onPressed: () => context.push(AppRoutes.aiAssistant),
              child: Text(l10n.aiGoToSetup),
            ),
        ],
      );
    }
    final onDevice = choice.isOnDevice;
    LocalRunPlan? plan;
    if (choice is AiLocalChoice) {
      // Starting on a remembered phone model that isn't the active one:
      // make it active, the engine loads the active model.
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
      // Still loading, or the picked model is becoming the active one.
      if (plan == null || plan.record.id != choice.record.id) {
        return const Center(child: CircularProgressIndicator());
      }
    }
    if (!_defaultsApplied && presets.isNotEmpty) {
      _defaultsApplied = true;
      _anonymize = settings.defaultAnonymizeTitles;
      if (onDevice) {
        _compact = true;
        _maxTransactions = aiCompactDefaultTransactions.toDouble();
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _selectPreset(presets.first, settings: settings),
      );
    }
    final draft = ref.watch(aiDraftControllerProvider);
    final walletsAsync = ref.watch(walletsListProvider);
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('model-${choice.key}'),
          initialValue: choice.key,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.aiRunModelLabel,
            prefixIcon: Icon(
              onDevice ? Icons.smartphone_outlined : Icons.cloud_outlined,
            ),
          ),
          items: [
            for (final c in choices)
              DropdownMenuItem(
                value: c.key,
                child: Text(
                  _choiceLabel(l10n, c),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (key) {
            for (final c in choices) {
              if (c.key == key) _selectChoice(c, choice);
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.aiWhatToAnalyze, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in presets)
              ChoiceChip(
                label: Text(p.title),
                selected: _preset?.id == p.id,
                onSelected: (_) => _selectPreset(p, settings: settings),
              ),
          ],
        ),
        if (_preset != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_preset!.description, style: theme.textTheme.bodySmall),
        ],
        if (_preset?.isCustom == true) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _question,
            minLines: 2,
            maxLines: 5,
            maxLength: aiInstructionsMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.aiCustomQuestionLabel,
              hintText: l10n.aiCustomQuestionHint,
              errorText: _questionError,
              alignLabelWithHint: true,
            ),
          ),
        ],
        if (_filters != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _FiltersCard(
            filters: _filters!,
            fromHistory: _fromHistory,
            onChanged: (f) => setState(() => _filters = f.isEmpty ? null : f),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.aiPeriodLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: l10n.aiDateFrom,
                emptyText: l10n.aiDateFromEmpty,
                value: _range.from,
                format: dateFormat,
                onTap: () => _pickDate(isFrom: true),
                onClear: () =>
                    setState(() => _range = (from: null, to: _range.to)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DateField(
                label: l10n.aiDateTo,
                emptyText: l10n.aiDateToEmpty,
                value: _range.to,
                format: dateFormat,
                onTap: () => _pickDate(isFrom: false),
                onClear: () =>
                    setState(() => _range = (from: _range.from, to: null)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in AiQuickPeriod.values)
              ChoiceChip(
                label: Text(aiQuickPeriodLabel(l10n, p)),
                selected: aiMatchQuick(_range, DateTime.now()) == p,
                onSelected: (_) =>
                    setState(() => _range = aiQuickRange(p, DateTime.now())),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.aiWalletsLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        walletsAsync.maybeWhen(
          data: (wallets) => Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              FilterChip(
                label: Text(l10n.aiAllWallets),
                selected: _walletIds.isEmpty,
                onSelected: (_) => setState(_walletIds.clear),
              ),
              for (final w in wallets)
                FilterChip(
                  label: Text(w.name),
                  selected: _walletIds.contains(w.id),
                  onSelected: (on) => setState(
                    () => on ? _walletIds.add(w.id) : _walletIds.remove(w.id),
                  ),
                ),
            ],
          ),
          orElse: () => const LinearProgressIndicator(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.aiDataToSend, style: theme.textTheme.titleMedium),
        Text(l10n.aiDataToSendHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in AiDataSection.values)
              FilterChip(
                label: Text(aiSectionLabel(l10n, s)),
                selected: _sections.contains(s),
                onSelected: (on) =>
                    setState(() => on ? _sections.add(s) : _sections.remove(s)),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiCompactProfile),
          subtitle: Text(
            onDevice
                ? l10n.aiCompactProfileHintLocal
                : l10n.aiCompactProfileHint,
          ),
          value: _compact,
          onChanged: _setCompact,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiIncludeTransactions),
          subtitle: Text(l10n.aiIncludeTransactionsHint),
          value: _includeTransactions,
          onChanged: (v) => setState(() => _includeTransactions = v),
        ),
        if (_includeTransactions)
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxTransactions,
                  min: _compact ? 10 : 50,
                  max: (_compact ? aiCompactMaxTransactions : aiMaxTransactions)
                      .toDouble(),
                  divisions: 9,
                  label: '${_maxTransactions.round()}',
                  onChanged: (v) => setState(() => _maxTransactions = v),
                ),
              ),
              Text(l10n.aiMaxTransactionsValue(_maxTransactions.round())),
            ],
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiDefaultAnonymizeTitles),
          subtitle: Text(l10n.aiDefaultAnonymizeTitlesHint),
          value: _anonymize,
          onChanged: (v) => setState(() => _anonymize = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiIncludeAdjustments),
          subtitle: Text(l10n.aiIncludeAdjustmentsHint),
          value: _includeAdjustments,
          onChanged: (v) => setState(() => _includeAdjustments = v),
        ),
        if (draft.error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _describeDraftError(draft.error!, l10n),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: draft.isLoading || _preset == null
              ? null
              : () => _preview(settings, choice, plan),
          icon: draft.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.visibility_outlined),
          label: Text(l10n.aiPreviewAction),
        ),
      ],
    );
  }

  String _describeDraftError(AppError e, AppLocalizations l10n) {
    final p = presentError(e, l10n);
    if (p.fieldErrors.isEmpty) return p.message;
    return [p.message, ...p.fieldErrors.values].join('\n');
  }
}

/// One bound of the period: tap to pick, × to leave it open.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.emptyText,
    required this.value,
    required this.format,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String emptyText;
  final DateTime? value;
  final DateFormat format;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: l10n.aiDateClear,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null ? emptyText : format.format(value!),
          style: value == null
              ? TextStyle(color: Theme.of(context).colorScheme.outline)
              : null,
        ),
      ),
    );
  }
}

/// The Cronologia filters the analysis is restricted to, each removable.
class _FiltersCard extends ConsumerWidget {
  const _FiltersCard({
    required this.filters,
    required this.fromHistory,
    required this.onChanged,
  });

  final AiAnalysisFilters filters;
  final bool fromHistory;
  final ValueChanged<AiAnalysisFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    String? categoryName;
    for (final c in categories) {
      if (c.id == filters.categoryId) categoryName = c.name;
    }
    String money(int minor) =>
        Money(minorUnits: minor, currency: 'EUR').format();

    final chips = <Widget>[
      if (filters.direction != null)
        InputChip(
          label: Text(
            filters.direction == 'DEBIT'
                ? l10n.aiFilterExpenses
                : l10n.aiFilterIncome,
          ),
          onDeleted: () => onChanged(filters.without(direction: true)),
        ),
      if (filters.categoryId != null)
        InputChip(
          label: Text(l10n.aiFilterCategory(categoryName ?? '…')),
          onDeleted: () => onChanged(filters.without(categoryId: true)),
        ),
      if (filters.title != null && filters.title!.isNotEmpty)
        InputChip(
          label: Text(l10n.aiFilterTitle(filters.title!)),
          onDeleted: () => onChanged(filters.without(title: true)),
        ),
      if (filters.amountMinMinor != null)
        InputChip(
          label: Text(l10n.aiFilterAmountMin(money(filters.amountMinMinor!))),
          onDeleted: () => onChanged(filters.without(amountMin: true)),
        ),
      if (filters.amountMaxMinor != null)
        InputChip(
          label: Text(l10n.aiFilterAmountMax(money(filters.amountMaxMinor!))),
          onDeleted: () => onChanged(filters.without(amountMax: true)),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    fromHistory
                        ? l10n.aiFiltersFromHistoryTitle
                        : l10n.aiFiltersTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.aiFiltersHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: chips,
            ),
          ],
        ),
      ),
    );
  }
}
