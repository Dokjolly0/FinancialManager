import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/engine_model_host.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';
import 'local_models_controller.dart';
import '../../../../core/platform/platform_info.dart';

/// Real tokens per server-estimated token for files outside the catalog
/// (the catalog models measured 1.56–1.75, docs/ai-on-device-spike.md).
const genericTokenFactor = 1.75;

/// Chat template and turn markers around the prompt.
const localPromptOverheadTokens = 256;

/// Speeds assumed when neither a measurement nor the catalog has one.
const fallbackLocalSpeed = LocalSpeed(prefillTps: 50, decodeTps: 8);

/// Reports measured in the prototype ran 600–1,100 tokens: estimates
/// assume this much output, or the limit if it is lower.
const expectedReportTokens = 900;

/// Where a time estimate's speeds come from.
enum LocalSpeedSource { measured, catalog, fallback }

/// Context use above this share shows amber.
const localContextTightShare = 0.85;

enum LocalContextLevel { ok, tight, overflow }

/// How much of the model's context a run takes, in real tokens.
class LocalContextUsage {
  const LocalContextUsage({
    required this.contextTokens,
    required this.inputTokens,
    required this.reservedOutputTokens,
    required this.exact,
  });

  final int contextTokens;
  final int inputTokens;
  final int reservedOutputTokens;

  /// True once the engine counted the prompt; otherwise estimated with the
  /// model's token factor.
  final bool exact;

  int get usedTokens =>
      inputTokens + reservedOutputTokens + localPromptOverheadTokens;

  double get share => usedTokens / contextTokens;

  LocalContextLevel get level => usedTokens > contextTokens
      ? LocalContextLevel.overflow
      : share > localContextTightShare
      ? LocalContextLevel.tight
      : LocalContextLevel.ok;
}

/// A duration shown as a ±30% range.
class LocalTimeEstimate {
  const LocalTimeEstimate(this.expected);

  final Duration expected;

  Duration get low => expected * 0.7;
  Duration get high => expected * 1.3;
}

/// What an on-device run of the active model will use: its parameters,
/// the token budget for the compact prompt, and speeds for time estimates.
class LocalRunPlan {
  const LocalRunPlan({
    required this.record,
    required this.params,
    required this.speed,
    required this.speedSource,
  });

  final LocalModelRecord record;
  final LocalRuntimeParams params;
  final LocalSpeed speed;
  final LocalSpeedSource speedSource;

  double get tokenFactor => record.tokenFactor ?? genericTokenFactor;

  /// The prompt budget in the server's estimated tokens: what is left of
  /// the context after the answer and the template, scaled down to the
  /// server's count. Within the server's 1,000..32,000 range.
  int get budgetTokens {
    final free =
        params.contextTokens -
        params.maxOutputTokens -
        localPromptOverheadTokens;
    return (free / tokenFactor).floor().clamp(1000, 32000);
  }

  AiDeviceParams get device => AiDeviceParams(
    contextTokens: params.contextTokens,
    maxOutputTokens: params.maxOutputTokens,
  );

  /// [estimatedInputTokens] is the server's estimate; [exactInputTokens]
  /// the engine's count when known.
  LocalContextUsage usage({
    required int estimatedInputTokens,
    int? exactInputTokens,
  }) => LocalContextUsage(
    contextTokens: params.contextTokens,
    inputTokens:
        exactInputTokens ?? (estimatedInputTokens * tokenFactor).ceil(),
    reservedOutputTokens: params.maxOutputTokens,
    exact: exactInputTokens != null,
  );

  /// Loading (unless the model is already loaded), reading the prompt and
  /// writing a typical report.
  LocalTimeEstimate estimate({required int inputTokens, bool loaded = false}) {
    final load = loaded
        ? 0.0
        : record.engine == LocalEngineKind.litertLm
        ? 5.0
        : 8.0;
    final out = math.min(params.maxOutputTokens, expectedReportTokens);
    final seconds =
        load + inputTokens / speed.prefillTps + out / speed.decodeTps;
    return LocalTimeEstimate(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Speeds for [record] on [backend]: the phone's own measurement, else
  /// the catalog's, else a cautious default.
  static (LocalSpeed, LocalSpeedSource) speedFor({
    required LocalSpeed? measured,
    required LocalModelSpec? spec,
    required LocalBackend backend,
  }) {
    if (measured != null) return (measured, LocalSpeedSource.measured);
    final listed = spec?.speed[backend];
    if (listed != null) return (listed, LocalSpeedSource.catalog);
    return (fallbackLocalSpeed, LocalSpeedSource.fallback);
  }
}

/// On-device models run on Android only (iOS builds, but the feature is
/// unavailable there; the web dashboard has no engines and uses cloud
/// providers only). Overridden in tests.
final localAiSupportedProvider = Provider<bool>((ref) => isAndroidApp);

/// The plan for the active model; null when none is installed. Refreshed
/// when the active model changes; invalidate after saving runtime
/// settings or measuring the speed.
final localRunPlanProvider = FutureProvider.autoDispose<LocalRunPlan?>((
  ref,
) async {
  final activeId = ref.watch(
    localModelsControllerProvider.select((s) => s.activeModelId),
  );
  final store = ref.watch(modelStoreProvider);
  final id = activeId ?? await store.activeModelId;
  final record = id == null ? null : await store.get(id);
  if (record == null) return null;
  final params = EngineModelHost.paramsFor(
    record,
    await store.runtimeChoice(record.id),
  );
  LocalModelSpec? spec;
  try {
    spec = (await ref.watch(localModelCatalogProvider.future)).byId(record.id);
  } catch (_) {
    spec = null;
  }
  final (speed, source) = LocalRunPlan.speedFor(
    measured: await store.speedOf(record.id, params.backend),
    spec: spec,
    backend: params.backend,
  );
  return LocalRunPlan(
    record: record,
    params: params,
    speed: speed,
    speedSource: source,
  );
});
