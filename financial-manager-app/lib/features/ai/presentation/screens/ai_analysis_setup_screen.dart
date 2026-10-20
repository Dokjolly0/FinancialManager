import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reports/domain/models/report_period.dart';
import '../../../reports/presentation/view_models/report_controller.dart';
import '../../../wallets/data/providers.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../view_models/ai_draft_controller.dart';
import '../widgets/ai_consent_sheet.dart';

String aiSectionLabel(AppLocalizations l10n, AiDataSection s) => switch (s) {
  AiDataSection.monthly => l10n.aiSectionMonthly,
  AiDataSection.categories => l10n.aiSectionCategories,
  AiDataSection.titles => l10n.aiSectionTitles,
  AiDataSection.transfers => l10n.aiSectionTransfers,
  AiDataSection.recurring => l10n.aiSectionRecurring,
  AiDataSection.personalContext => l10n.aiSectionPersonalContext,
};

String aiPeriodLabel(AppLocalizations l10n, ReportPreset p) => switch (p) {
  ReportPreset.last30Days => l10n.aiPeriodLast30Days,
  ReportPreset.last12Months => l10n.aiPeriodLast12Months,
  ReportPreset.currentMonth => l10n.aiPeriodCurrentMonth,
  ReportPreset.currentYear => l10n.aiPeriodCurrentYear,
  ReportPreset.allTime => l10n.aiPeriodAllTime,
  ReportPreset.custom => l10n.aiPeriodCustom,
};

/// Reports → Analisi AI (plan.md section 32.7): choose what to analyze and
/// what data to send, then open the preview.
class AiAnalysisSetupScreen extends ConsumerStatefulWidget {
  const AiAnalysisSetupScreen({super.key});

  @override
  ConsumerState<AiAnalysisSetupScreen> createState() =>
      _AiAnalysisSetupScreenState();
}

class _AiAnalysisSetupScreenState extends ConsumerState<AiAnalysisSetupScreen> {
  AiPreset? _preset;
  late ReportPreset _period;
  DateTimeRange? _customRange;
  final Set<String> _walletIds = {};
  Set<AiDataSection> _sections = {};
  bool _includeTransactions = false;
  double _maxTransactions = aiDefaultMaxTransactions.toDouble();
  bool _anonymize = false;
  bool _includeAdjustments = false;
  final _question = TextEditingController();
  bool _defaultsApplied = false;
  String? _questionError;

  @override
  void initState() {
    super.initState();
    // Start from what the Reports screen is showing.
    final report = ref.read(reportControllerProvider);
    _period = report.period.preset;
    if (_period == ReportPreset.custom &&
        report.period.customFrom != null &&
        report.period.customTo != null) {
      _customRange = DateTimeRange(
        start: report.period.customFrom!,
        end: report.period.customTo!,
      );
    }
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _period = ReportPreset.custom;
      });
    }
  }

  Future<void> _preview(AiSettings settings) async {
    final l10n = AppLocalizations.of(context);
    final preset = _preset;
    if (preset == null) return;
    if (preset.isCustom && _question.text.trim().isEmpty) {
      setState(() => _questionError = l10n.errorCodeRequiredField);
      return;
    }
    if (_period == ReportPreset.custom && _customRange == null) {
      await _pickRange();
      if (_customRange == null) return;
    }
    if (settings.consent.required) {
      if (!mounted) return;
      final accepted = await AiConsentSheet.show(
        context,
        consentVersion: settings.consent.currentVersion,
      );
      if (!accepted) return;
    }

    final request = AiAnalysisRequest(
      preset: preset.id,
      periodPreset: _period.toApi(),
      customFrom: _customRange?.start,
      customTo: _customRange?.end,
      walletIds: _walletIds.toList(),
      sections: _sections,
      includeTransactions: _includeTransactions,
      maxTransactions: _maxTransactions.round(),
      anonymizeTitles: _anonymize,
      includeAdjustments: _includeAdjustments,
      instructions: preset.isCustom ? _question.text.trim() : null,
    );
    final ok = await ref
        .read(aiDraftControllerProvider.notifier)
        .preview(request);
    if (ok && mounted) context.push(AppRoutes.aiPreview);
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
    if (!settings.available || !settings.setup.providerReady) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(l10n.aiNotReadyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            settings.available ? l10n.aiNotReadyBody : l10n.aiUnavailableBody,
          ),
          const SizedBox(height: AppSpacing.md),
          if (settings.available)
            FilledButton(
              onPressed: () => context.push(AppRoutes.aiAssistant),
              child: Text(l10n.aiGoToSetup),
            ),
        ],
      );
    }
    if (!_defaultsApplied && presets.isNotEmpty) {
      _defaultsApplied = true;
      _anonymize = settings.defaultAnonymizeTitles;
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
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.aiPeriodLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final p in ReportPreset.values)
              ChoiceChip(
                label: Text(
                  p == ReportPreset.custom && _customRange != null
                      ? '${dateFormat.format(_customRange!.start)} – ${dateFormat.format(_customRange!.end)}'
                      : aiPeriodLabel(l10n, p),
                ),
                selected: _period == p,
                onSelected: (_) => p == ReportPreset.custom
                    ? _pickRange()
                    : setState(() => _period = p),
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
                  min: 50,
                  max: aiMaxTransactions.toDouble(),
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
              : () => _preview(settings),
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
