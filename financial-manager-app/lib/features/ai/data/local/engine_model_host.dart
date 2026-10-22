import 'dart:async';

import '../../domain/local/local_llm_engine.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';
import 'device_capabilities_source.dart';
import 'model_store.dart';

/// Hands the runner a loaded engine for the active model (plan.md
/// section 33).
///
/// - One model is loaded at a time: a different model or different
///   context/backend unloads the previous one first.
/// - The model is unloaded after [idleTimeout] without runs (never while
///   it generates), on [release], and on memory pressure.
/// - A phone at thermal status SEVERE or worse is refused before anything
///   loads ([LocalErrorCodes.tooHot]).
/// - The session reports the backend the model actually runs on.
class EngineModelHost implements LocalModelHost {
  EngineModelHost({
    required ModelStore store,
    required Map<LocalEngineKind, LocalLlmEngine> engines,
    required DeviceCapabilitiesSource device,
    this.idleTimeout = const Duration(minutes: 5),
  }) : _store = store,
       _engines = engines,
       _device = device;

  final ModelStore _store;
  final Map<LocalEngineKind, LocalLlmEngine> _engines;
  final DeviceCapabilitiesSource _device;
  final Duration idleTimeout;

  LocalSession? _loaded;
  String? _loadedKey;
  Timer? _idle;
  Future<void> _pending = Future.value();

  static const defaultTemperature = 0.2;
  static const defaultMaxOutputTokens = 1024;

  /// What a run of [record] uses, given the user's [choice].
  static LocalRuntimeParams paramsFor(
    LocalModelRecord record,
    LocalRuntimeChoice? choice,
  ) {
    final backends = record.backends.isEmpty
        ? defaultBackendsFor(record.engine)
        : record.backends;
    final backend = backends.contains(choice?.backend)
        ? choice!.backend!
        : backends.first;
    final maxContext = backend == LocalBackend.cpu
        ? (record.maxContextTokensCpu ?? record.maxContextTokens)
        : record.maxContextTokens;
    final context = (choice?.contextTokens ?? record.defaultContextTokens)
        .clamp(2048, maxContext);
    final maxOutput = (choice?.maxOutputTokens ?? defaultMaxOutputTokens).clamp(
      256,
      context ~/ 2,
    );
    return LocalRuntimeParams(
      contextTokens: context,
      maxOutputTokens: maxOutput,
      temperature: (choice?.temperature ?? defaultTemperature).clamp(0.0, 1.0),
      backend: backend,
    );
  }

  @override
  Future<LocalSession> acquire({String? modelId}) => _serial(() async {
    final caps = await _device.read();
    if (caps?.isHot ?? false) {
      throw const LocalEngineException(LocalErrorCodes.tooHot);
    }
    var record = modelId == null ? null : await _store.get(modelId);
    var path = record == null ? null : await _store.pathOf(record);
    if (path == null) {
      final id = await _store.activeModelId;
      record = id == null ? null : await _store.get(id);
      path = record == null ? null : await _store.pathOf(record);
    }
    if (record == null || path == null) {
      throw const LocalEngineException(LocalErrorCodes.modelMissing);
    }
    final engine = _engines[record.engine];
    if (engine == null || !await engine.isSupported()) {
      throw const LocalEngineException(LocalErrorCodes.unsupported);
    }
    final params = paramsFor(record, await _store.runtimeChoice(record.id));
    final key = '${record.id}|${params.contextTokens}|${params.backend.wire}';
    final current = _loaded;
    if (current == null ||
        _loadedKey != key ||
        !identical(current.engine, engine) ||
        !engine.isLoaded) {
      await _unload();
      final model = record.toInstalled(path);
      await engine.load(model, params);
      _loaded = LocalSession(
        engine: engine,
        model: model,
        params: params.copyWith(backend: engine.activeBackend),
      );
      _loadedKey = key;
    } else {
      // Same model, maybe new output limit or temperature: no reload.
      _loaded = LocalSession(
        engine: engine,
        model: current.model,
        params: LocalRuntimeParams(
          contextTokens: params.contextTokens,
          maxOutputTokens: params.maxOutputTokens,
          temperature: params.temperature,
          backend: current.params.backend,
        ),
      );
    }
    _armIdle();
    return _loaded!;
  });

  @override
  void recordSpeed(LocalSession session, LocalGenStats stats) {
    _armIdle();
    if (stats.prefillMs <= 0 || stats.decodeMs <= 0 || stats.outputTokens < 2) {
      return;
    }
    unawaited(
      _store
          .recordSpeed(
            session.model.id,
            session.params.backend,
            LocalSpeed(
              prefillTps: stats.promptTokens / (stats.prefillMs / 1000),
              decodeTps: (stats.outputTokens - 1) / (stats.decodeMs / 1000),
            ),
          )
          .catchError((_) {}),
    );
  }

  @override
  Future<void> release() => _serial(_unload);

  /// The system is short of memory: drop the model unless it is working.
  Future<void> onMemoryPressure() => _serial(() async {
    if (_loaded?.engine.isGenerating ?? false) return;
    await _unload();
  });

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, () {
      if (_loaded?.engine.isGenerating ?? false) {
        _armIdle();
      } else {
        unawaited(_serial(_unload));
      }
    });
  }

  Future<void> _unload() async {
    _idle?.cancel();
    final s = _loaded;
    _loaded = null;
    _loadedKey = null;
    if (s != null) await s.engine.unload();
  }

  /// Loads and unloads happen one at a time.
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then((_) {}, onError: (_) {});
    return next;
  }
}
