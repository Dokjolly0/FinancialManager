import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_llama/flutter_edge_ai_llama.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../domain/local/local_llm_engine.dart';
import '../../../domain/models/local_model.dart';
import 'chat_transcript.dart';

/// LiteRT-LM or llama.cpp through flutter_edge_ai (plan.md section 33,
/// choices measured in docs/ai-on-device-spike.md):
/// - no silent fallback between backends, and float32 activations on the
///   GPU (LiteRT-LM's float16 default writes wrong digits on long prompts);
///   [activeBackend] reports where the model really runs;
/// - token counts come from the model's tokenizer;
/// - the screen stays on while a model generates.
class EdgeAiEngine implements LocalLlmEngine {
  EdgeAiEngine(this.kind);

  @override
  final LocalEngineKind kind;

  InferenceModel? _model;
  InferenceModelSession? _session;
  bool _generating = false;

  static Future<void>? _initialized;

  /// Registers both engines with flutter_edge_ai, once per process.
  static Future<void> _initialize() =>
      _initialized ??= FlutterEdgeAi.initialize(
        inferenceEngines: const [
          LiteRtLmEngine(backendFallback: false),
          LlamaEngineProvider(),
        ],
      );

  @override
  Future<bool> isSupported() async =>
      Platform.isAndroid && Abi.current() == Abi.androidArm64;

  @override
  bool get isLoaded => _model != null && !_model!.isClosed;

  @override
  bool get isGenerating => _generating;

  @override
  LocalBackend? get activeBackend =>
      switch (isLoaded ? _model!.activeBackend : null) {
        PreferredBackend.gpu => LocalBackend.gpu,
        PreferredBackend.npu => LocalBackend.npu,
        PreferredBackend.cpu => LocalBackend.cpu,
        null => null,
      };

  @override
  Future<void> load(
    InstalledLocalModel model,
    LocalRuntimeParams params,
  ) async {
    if (!await isSupported()) {
      throw const LocalEngineException(LocalErrorCodes.unsupported);
    }
    await unload();
    try {
      await _initialize();
      await FlutterEdgeAi.installModel(
        modelType: _modelType(model.modelType),
        fileType: kind == LocalEngineKind.litertLm
            ? ModelFileType.litertlm
            : ModelFileType.gguf,
      ).fromFile(model.path).install();
      _model = await FlutterEdgeAi.getActiveModel(
        maxTokens: params.contextTokens,
        preferredBackend: _preferred(params.backend),
        activationDataType:
            kind == LocalEngineKind.litertLm &&
                params.backend == LocalBackend.gpu
            ? ActivationDataType.float32
            : null,
      );
    } catch (e) {
      _model = null;
      throw _mapError(e);
    }
  }

  @override
  Future<int?> countTokens(String text) async {
    final model = _model;
    if (model == null) return null;
    try {
      final existing = _session;
      if (existing != null) return await existing.sizeInTokens(text);
      final s = await model.createSession();
      try {
        return await s.sizeInTokens(text);
      } finally {
        await s.close();
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<LocalGenEvent> generate(LocalChatRequest request) {
    final out = StreamController<LocalGenEvent>();
    out.onListen = () => _generate(request, out);
    out.onCancel = cancel;
    return out.stream;
  }

  Future<void> _generate(
    LocalChatRequest request,
    StreamController<LocalGenEvent> out,
  ) async {
    final model = _model;
    if (model == null) {
      out.addError(const LocalEngineException(LocalErrorCodes.modelMissing));
      await out.close();
      return;
    }
    _generating = true;
    unawaited(WakelockPlus.enable().catchError((_) {}));
    InferenceModelSession? session;
    try {
      final p = request.params;
      session = _session = await model.createSession(
        temperature: p.temperature,
        topK: p.topK,
        topP: p.topP,
        systemInstruction: request.system,
        maxOutputTokens: p.maxOutputTokens,
      );
      final user = chatTranscript(request.messages);
      final promptTokens = await session.sizeInTokens(
        '${request.system}\n\n$user',
      );
      await session.addQueryChunk(Message.text(text: user, isUser: true));

      final sw = Stopwatch()..start();
      int? firstMs;
      final text = StringBuffer();
      await for (final piece in session.getResponseAsync()) {
        if (piece.isEmpty) continue;
        firstMs ??= sw.elapsedMilliseconds;
        text.write(piece);
        if (out.hasListener) out.add(LocalGenDelta(piece));
      }
      final totalMs = sw.elapsedMilliseconds;
      // llama.cpp streams text in chunks of many tokens: count the answer
      // with the tokenizer rather than the stream events.
      final outputTokens = text.isEmpty
          ? 0
          : await session.sizeInTokens(text.toString());
      out.add(
        LocalGenStats(
          promptTokens: promptTokens,
          outputTokens: outputTokens,
          prefillMs: firstMs ?? totalMs,
          decodeMs: firstMs == null ? 0 : totalMs - firstMs,
          truncated: outputTokens >= p.maxOutputTokens - 1,
        ),
      );
    } catch (e) {
      if (!out.isClosed) out.addError(_mapError(e));
    } finally {
      _session = null;
      _generating = false;
      try {
        await session?.close();
      } catch (_) {}
      unawaited(WakelockPlus.disable().catchError((_) {}));
      await out.close();
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _session?.stopGeneration();
    } catch (_) {}
  }

  @override
  Future<void> unload() async {
    final m = _model;
    _model = null;
    if (m == null) return;
    await cancel();
    try {
      await m.close();
    } catch (_) {}
  }

  static ModelType _modelType(String name) {
    for (final t in ModelType.values) {
      if (t.name == name) return t;
    }
    return ModelType.general;
  }

  static PreferredBackend _preferred(LocalBackend b) => switch (b) {
    LocalBackend.cpu => PreferredBackend.cpu,
    LocalBackend.gpu => PreferredBackend.gpu,
    LocalBackend.npu => PreferredBackend.npu,
  };

  static LocalEngineException _mapError(Object e) {
    if (e is LocalEngineException) return e;
    final s = e.toString();
    final lower = s.toLowerCase();
    if (lower.contains('out of memory') ||
        lower.contains('outofmemory') ||
        lower.contains('oom') ||
        lower.contains('failed to allocate')) {
      return LocalEngineException(LocalErrorCodes.outOfMemory, s);
    }
    if (lower.contains('context') &&
        (lower.contains('exceed') || lower.contains('too long'))) {
      return LocalEngineException(LocalErrorCodes.contextTooLong, s);
    }
    return LocalEngineException(LocalErrorCodes.engine, s);
  }
}
