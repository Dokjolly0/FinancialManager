import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_catalog.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_run_plan.dart';

LocalModelRecord record({double? tokenFactor = 1.6}) => LocalModelRecord(
  id: 'gemma',
  engine: LocalEngineKind.litertLm,
  modelType: 'gemma4',
  displayName: 'Gemma 4 E2B',
  quantization: 'int4',
  fileName: 'm.litertlm',
  sizeBytes: 10,
  sha256: 'a' * 64,
  verified: true,
  source: LocalModelSource.catalog,
  installedAt: DateTime.utc(2026, 10, 21),
  defaultContextTokens: 16384,
  maxContextTokens: 16384,
  maxContextTokensCpu: 8192,
  backends: const [LocalBackend.gpu, LocalBackend.cpu],
  tokenFactor: tokenFactor,
);

LocalRunPlan plan({
  int context = 4096,
  int output = 1024,
  double? tokenFactor = 1.6,
  LocalSpeed speed = const LocalSpeed(prefillTps: 500, decodeTps: 25),
}) => LocalRunPlan(
  record: record(tokenFactor: tokenFactor),
  params: LocalRuntimeParams(
    contextTokens: context,
    maxOutputTokens: output,
    backend: LocalBackend.gpu,
  ),
  speed: speed,
  speedSource: LocalSpeedSource.catalog,
);

void main() {
  test('the budget leaves room for the answer and the template, in the '
      'server\'s tokens', () {
    // (16384 - 1024 - 256) / 1.6 = 9440
    expect(plan(context: 16384).budgetTokens, 9440);
    // Imports use the generic factor.
    expect(
      plan(context: 16384, tokenFactor: null).budgetTokens,
      ((16384 - 1024 - 256) / genericTokenFactor).floor(),
    );
    // Never below the server's minimum.
    expect(plan(context: 2048, output: 1024).budgetTokens, 1000);
  });

  test('context usage: estimated with the factor, exact when counted', () {
    final p = plan();
    final est = p.usage(estimatedInputTokens: 1000);
    expect(est.inputTokens, 1600);
    expect(est.exact, isFalse);
    expect(est.usedTokens, 1600 + 1024 + 256);
    expect(est.level, LocalContextLevel.ok);

    final exact = p.usage(estimatedInputTokens: 1000, exactInputTokens: 2600);
    expect(exact.exact, isTrue);
    expect(exact.level, LocalContextLevel.tight, reason: '3880 / 4096');

    expect(
      p.usage(estimatedInputTokens: 2000).level,
      LocalContextLevel.overflow,
    );
  });

  test('time estimate: load, reading and a typical report, ±30%', () {
    final p = plan(output: 2048);
    // 5 s load + 1000 / 500 + 900 / 25 = 43 s.
    final cold = p.estimate(inputTokens: 1000);
    expect(cold.expected, const Duration(seconds: 43));
    expect(cold.low, const Duration(milliseconds: 30100));
    expect(cold.high, const Duration(milliseconds: 55900));
    expect(
      p.estimate(inputTokens: 1000, loaded: true).expected,
      const Duration(seconds: 38),
    );
    // A lower output limit caps the expected answer.
    expect(
      plan(output: 256).estimate(inputTokens: 0, loaded: true).expected,
      Duration(milliseconds: (256 / 25 * 1000).round()),
    );
  });

  test('speeds: measured, else the catalog, else a cautious default', () {
    const measured = LocalSpeed(prefillTps: 700, decodeTps: 31);
    final spec = LocalModelSpec.fromJson({
      'id': 'gemma',
      'family': 'gemma4',
      'display_name': 'Gemma',
      'engine': 'litert_lm',
      'format': 'litertlm',
      'model_type': 'gemma4',
      'quantization': 'int4',
      'url': 'https://huggingface.co/o/r/resolve/${'0' * 40}/m.litertlm',
      'revision': '0' * 40,
      'sha256': 'a' * 64,
      'size_bytes': 1,
      'ram_min_mb': 1,
      'ram_recommended_mb': 2,
      'context_default': 4096,
      'context_max': 4096,
      'backends': ['gpu'],
      'token_factor': 1.6,
      'speed': {
        'gpu': {'prefill_tps': 600, 'decode_tps': 30},
      },
      'notes': {'it': 'n', 'en': 'n'},
      'license': {'id': 'apache-2.0', 'url': 'https://x', 'gated': false},
    });
    expect(
      LocalRunPlan.speedFor(
        measured: measured,
        spec: spec,
        backend: LocalBackend.gpu,
      ),
      (measured, LocalSpeedSource.measured),
    );
    final (listed, source) = LocalRunPlan.speedFor(
      measured: null,
      spec: spec,
      backend: LocalBackend.gpu,
    );
    expect(listed.prefillTps, 600);
    expect(source, LocalSpeedSource.catalog);
    expect(
      LocalRunPlan.speedFor(
        measured: null,
        spec: spec,
        backend: LocalBackend.cpu,
      ).$2,
      LocalSpeedSource.fallback,
    );
  });
}
