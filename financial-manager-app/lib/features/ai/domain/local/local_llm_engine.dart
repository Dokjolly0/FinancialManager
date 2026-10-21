import '../models/local_model.dart';

/// Failure codes an engine reports; they are also the AI_LOCAL_* codes the
/// server stores and the app localizes.
abstract final class LocalErrorCodes {
  static const engine = 'AI_LOCAL_ENGINE_ERROR';
  static const outOfMemory = 'AI_LOCAL_OUT_OF_MEMORY';
  static const contextTooLong = 'AI_LOCAL_CONTEXT_TOO_LONG';
  static const timeout = 'AI_LOCAL_TIMEOUT';
  static const modelMissing = 'AI_LOCAL_MODEL_MISSING';
  static const interrupted = 'AI_LOCAL_INTERRUPTED';
  static const unsupported = 'AI_LOCAL_UNSUPPORTED';

  /// Thermal status SEVERE or worse: refused before the server is asked,
  /// so it never reaches the server's list.
  static const tooHot = 'AI_LOCAL_TOO_HOT';
}

class LocalEngineException implements Exception {
  const LocalEngineException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'LocalEngineException($code${message == null ? '' : ': $message'})';
}

class LocalChatRequest {
  const LocalChatRequest({
    required this.system,
    required this.messages,
    required this.params,
  });

  final String system;
  final List<LocalChatMessage> messages;
  final LocalRuntimeParams params;
}

/// What a generation emits: text pieces, then one stats event.
sealed class LocalGenEvent {
  const LocalGenEvent();
}

final class LocalGenDelta extends LocalGenEvent {
  const LocalGenDelta(this.text);

  final String text;
}

final class LocalGenStats extends LocalGenEvent {
  const LocalGenStats({
    required this.promptTokens,
    required this.outputTokens,
    this.prefillMs = 0,
    this.decodeMs = 0,
    this.truncated = false,
  });

  final int promptTokens;
  final int outputTokens;
  final int prefillMs;
  final int decodeMs;

  /// Generation stopped at the output token limit.
  final bool truncated;
}

/// One on-device inference engine (LiteRT-LM or llama.cpp). Implementations
/// apply the model's chat template themselves; models without a system role
/// get the system text before the first user turn.
abstract interface class LocalLlmEngine {
  LocalEngineKind get kind;

  /// Whether this device can run the engine at all.
  Future<bool> isSupported();

  Future<void> load(InstalledLocalModel model, LocalRuntimeParams params);

  bool get isLoaded;

  /// Where the loaded model actually runs, which can differ from the
  /// backend asked for; null when nothing is loaded.
  LocalBackend? get activeBackend;

  /// True from the start of [generate] until its stream ends.
  bool get isGenerating;

  /// Exact token count of [text] with the loaded model's tokenizer, or
  /// null when the engine can't tell (callers then estimate).
  Future<int?> countTokens(String text);

  /// Streams the answer. Errors are [LocalEngineException]s. After
  /// [cancel] the stream ends early without an error.
  Stream<LocalGenEvent> generate(LocalChatRequest request);

  Future<void> cancel();

  Future<void> unload();
}

/// The model and engine an on-device run uses.
class LocalSession {
  const LocalSession({
    required this.engine,
    required this.model,
    required this.params,
  });

  final LocalLlmEngine engine;
  final InstalledLocalModel model;
  final LocalRuntimeParams params;
}

/// Provides a loaded engine for the active model. Implemented by the model
/// manager; [acquire] throws [LocalEngineException] with
/// [LocalErrorCodes.modelMissing] when no usable model is installed.
abstract interface class LocalModelHost {
  Future<LocalSession> acquire();

  /// Measured speed of a finished generation, to improve time estimates.
  void recordSpeed(LocalSession session, LocalGenStats stats);

  /// Unloads the model now (it was deleted, or memory is needed).
  Future<void> release();
}
