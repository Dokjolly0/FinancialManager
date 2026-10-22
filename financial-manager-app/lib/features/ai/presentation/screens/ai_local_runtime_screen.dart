import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/local/local_llm_engine.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/local_model_labels.dart';

/// Assistente AI → Impostazioni di esecuzione (plan.md section 33): how the
/// active model runs, and "Misura velocità".
class AiLocalRuntimeScreen extends ConsumerWidget {
  const AiLocalRuntimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final planAsync = ref.watch(localRunPlanProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiLocalRuntimeTitle)),
      // Saving refreshes the plan: keep the form (and a measurement in
      // progress) while it reloads.
      body: switch ((planAsync.value, planAsync)) {
        (final plan?, _) => _RuntimeForm(
          key: ValueKey(plan.record.id),
          plan: plan,
        ),
        (_, AsyncError()) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: l10n.errorCodeUnknownError,
            onRetry: () => ref.invalidate(localRunPlanProvider),
          ),
        ),
        (_, AsyncData()) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.aiLocalNoModel),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.pushReplacement(AppRoutes.aiLocalModels),
              child: Text(l10n.aiLocalChooseModel),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RuntimeForm extends ConsumerStatefulWidget {
  const _RuntimeForm({super.key, required this.plan});

  final LocalRunPlan plan;

  @override
  ConsumerState<_RuntimeForm> createState() => _RuntimeFormState();
}

class _RuntimeFormState extends ConsumerState<_RuntimeForm> {
  late LocalBackend _backend;
  late double _context;
  late double _output;
  late double _temperature;
  bool _busy = false;
  bool _measuring = false;
  LocalSpeed? _measured;
  String? _error;

  LocalModelRecord get _record => widget.plan.record;

  @override
  void initState() {
    super.initState();
    final p = widget.plan.params;
    _backend = p.backend;
    _context = p.contextTokens.toDouble();
    _output = p.maxOutputTokens.toDouble();
    _temperature = p.temperature;
  }

  int get _maxContext => _backend == LocalBackend.cpu
      ? (_record.maxContextTokensCpu ?? _record.maxContextTokens)
      : _record.maxContextTokens;

  int get _maxOutput => math.min(4096, _context.round() ~/ 2);

  void _setBackend(LocalBackend b) => setState(() {
    _backend = b;
    _context = math.min(_context, _maxContext.toDouble());
    _output = math.min(_output, _maxOutput.toDouble());
  });

  LocalRuntimeChoice get _choice => LocalRuntimeChoice(
    backend: _backend,
    contextTokens: _context.round(),
    maxOutputTokens: _output.round(),
    temperature: double.parse(_temperature.toStringAsFixed(2)),
  );

  Future<void> _save({bool pop = true}) async {
    setState(() => _busy = true);
    await ref.read(modelStoreProvider).setRuntimeChoice(_record.id, _choice);
    ref.invalidate(localRunPlanProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    if (pop) context.pop();
  }

  Future<void> _reset() async {
    await ref.read(modelStoreProvider).setRuntimeChoice(_record.id, null);
    ref.invalidate(localRunPlanProvider);
    if (mounted) context.pop();
  }

  /// Saves first: the benchmark runs the model as configured.
  Future<void> _measure() async {
    setState(() {
      _measuring = true;
      _error = null;
      _measured = null;
    });
    try {
      await _save(pop: false);
      final speed = await ref.read(modelBenchmarkProvider).run();
      if (mounted) setState(() => _measured = speed);
    } on LocalEngineException catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = localizeErrorCode(AppLocalizations.of(context), e.code),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context).errorCodeAiLocalEngineError,
        );
      }
    } finally {
      if (mounted) setState(() => _measuring = false);
      ref.invalidate(localRunPlanProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final plan = widget.plan;
    final speed = _measured ?? plan.speed;
    final speedSource = _measured != null
        ? LocalSpeedSource.measured
        : plan.speedSource;
    final backends = _record.backends.isEmpty
        ? defaultBackendsFor(_record.engine)
        : _record.backends;
    final contextMin = 2048.0;
    final contextMax = _maxContext.toDouble();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(_record.label, style: theme.textTheme.titleMedium),
        Text(_record.engine.label, style: theme.textTheme.bodySmall),
        if (backends.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.aiLocalBackendLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<LocalBackend>(
            segments: [
              for (final b in backends)
                ButtonSegment(
                  value: b,
                  label: Text(localBackendLabel(l10n, b)),
                ),
            ],
            selected: {_backend},
            onSelectionChanged: (s) => _setBackend(s.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _backend == LocalBackend.gpu
                ? l10n.aiLocalBackendGpuHint
                : l10n.aiLocalBackendCpuHint,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aiLocalContextLabel(numbers.format(_context.round())),
          style: theme.textTheme.titleSmall,
        ),
        if (contextMax > contextMin)
          Slider(
            value: _context.clamp(contextMin, contextMax),
            min: contextMin,
            max: contextMax,
            divisions: ((contextMax - contextMin) / 1024).round(),
            label: formatContextTokens(_context.round()),
            onChanged: (v) => setState(() {
              _context = v;
              _output = math.min(_output, _maxOutput.toDouble());
            }),
          ),
        Text(
          _context > _record.defaultContextTokens
              ? l10n.aiLocalContextMemoryWarning
              : l10n.aiLocalContextHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _context > _record.defaultContextTokens
                ? Colors.amber.shade800
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aiLocalOutputLabel(numbers.format(_output.round())),
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          value: _output.clamp(256, _maxOutput.toDouble()),
          min: 256,
          max: _maxOutput.toDouble(),
          divisions: math.max(1, (_maxOutput - 256) ~/ 128),
          label: '${_output.round()}',
          onChanged: (v) => setState(() => _output = v),
        ),
        Text(l10n.aiLocalOutputHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aiLocalTemperatureLabel(_temperature.toStringAsFixed(2)),
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          value: _temperature,
          min: 0,
          max: 1,
          divisions: 20,
          label: _temperature.toStringAsFixed(2),
          onChanged: (v) => setState(() => _temperature = v),
        ),
        Text(l10n.aiLocalTemperatureHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.aiLocalSpeedTitle, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.aiLocalSpeedValue(
                    numbers.format(speed.prefillTps.round()),
                    numbers.format(speed.decodeTps.round()),
                  ),
                ),
                Text(switch (speedSource) {
                  LocalSpeedSource.measured => l10n.aiLocalSpeedMeasured,
                  LocalSpeedSource.catalog => l10n.aiLocalSpeedCatalog,
                  LocalSpeedSource.fallback => l10n.aiLocalSpeedFallback,
                }, style: theme.textTheme.bodySmall),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _measuring || _busy ? null : _measure,
                  icon: _measuring
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed),
                  label: Text(
                    _measuring ? l10n.aiLocalMeasuring : l10n.aiLocalMeasure,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy || _measuring ? null : _save,
          child: Text(l10n.aiSaveSettings),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: _busy || _measuring ? null : _reset,
          child: Text(l10n.aiLocalResetDefaults),
        ),
      ],
    );
  }
}
