import 'dart:async';

import 'package:financialmanager/features/ai/domain/local/local_llm_engine.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';

/// A scripted engine: emits [deltas] with [delay] between them, then
/// stats, or throws [error] after [errorAfter] deltas.
class FakeLocalEngine implements LocalLlmEngine {
  FakeLocalEngine({
    this.deltas = const ['Ciao ', 'mondo'],
    this.delay = Duration.zero,
    this.error,
    this.errorAfter = 0,
    this.tokensPerChar,
  });

  List<String> deltas;
  Duration delay;
  LocalEngineException? error;
  int errorAfter;

  /// When set, countTokens returns length * this; null means "can't count".
  double? tokensPerChar;

  LocalChatRequest? lastRequest;
  bool cancelled = false;
  bool _loaded = false;
  Completer<void>? _cancel;

  @override
  LocalEngineKind get kind => LocalEngineKind.llamaCpp;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> load(
    InstalledLocalModel model,
    LocalRuntimeParams params,
  ) async => _loaded = true;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<int?> countTokens(String text) async =>
      tokensPerChar == null ? null : (text.length * tokensPerChar!).ceil();

  @override
  Stream<LocalGenEvent> generate(LocalChatRequest request) async* {
    lastRequest = request;
    cancelled = false;
    _cancel = Completer<void>();
    var sent = 0;
    for (final d in deltas) {
      if (error != null && sent == errorAfter) throw error!;
      if (delay > Duration.zero) {
        await Future.any([Future<void>.delayed(delay), _cancel!.future]);
      }
      if (cancelled) return;
      yield LocalGenDelta(d);
      sent++;
    }
    if (error != null) throw error!;
    yield LocalGenStats(
      promptTokens: 100,
      outputTokens: deltas.length,
      decodeMs: 10,
    );
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (_cancel != null && !_cancel!.isCompleted) _cancel!.complete();
  }

  @override
  Future<void> unload() async => _loaded = false;
}

class FakeModelHost implements LocalModelHost {
  FakeModelHost(this.engine, {this.contextTokens = 8192, this.missing = false});

  final FakeLocalEngine engine;
  final int contextTokens;
  final bool missing;
  final List<LocalGenStats> speeds = [];

  static const model = InstalledLocalModel(
    id: 'qwen3-4b-q4_k_m',
    engine: LocalEngineKind.llamaCpp,
    displayName: 'Qwen3 4B',
    quantization: 'Q4_K_M',
    path: '/models/qwen.gguf',
    defaultContextTokens: 8192,
    maxContextTokens: 32768,
  );

  @override
  Future<LocalSession> acquire() async {
    if (missing) throw const LocalEngineException(LocalErrorCodes.modelMissing);
    return LocalSession(
      engine: engine,
      model: model,
      params: LocalRuntimeParams(
        contextTokens: contextTokens,
        maxOutputTokens: 512,
      ),
    );
  }

  @override
  void recordSpeed(LocalSession session, LocalGenStats stats) =>
      speeds.add(stats);
}
