/// On-device analysis (plan.md section 33): what runs on the phone.
library;

/// Inference engines the app can drive.
enum LocalEngineKind {
  litertLm('litert_lm', 'LiteRT-LM'),
  llamaCpp('llama_cpp', 'llama.cpp');

  const LocalEngineKind(this.wire, this.label);

  final String wire;
  final String label;

  static LocalEngineKind? fromWire(String? value) {
    for (final k in LocalEngineKind.values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

/// Where the engine computes.
enum LocalBackend {
  cpu('cpu'),
  gpu('gpu'),
  npu('npu');

  const LocalBackend(this.wire);

  final String wire;

  static LocalBackend fromWire(String? value) => LocalBackend.values.firstWhere(
    (b) => b.wire == value,
    orElse: () => LocalBackend.cpu,
  );
}

/// A model file installed on this phone.
class InstalledLocalModel {
  const InstalledLocalModel({
    required this.id,
    required this.engine,
    required this.displayName,
    required this.quantization,
    required this.path,
    required this.defaultContextTokens,
    required this.maxContextTokens,
    this.maxContextTokensCpu,
    this.modelType = 'general',
    this.verified = true,
  });

  final String id;
  final LocalEngineKind engine;
  final String displayName;
  final String quantization;
  final String path;
  final int defaultContextTokens;
  final int maxContextTokens;

  /// Lower ceiling on the CPU, where LiteRT-LM needs much more memory.
  final int? maxContextTokensCpu;

  /// The engine package's model type (chat template); "general" lets the
  /// engine read the template from the file.
  final String modelType;

  /// False for an imported file whose checksum wasn't known.
  final bool verified;

  /// The label shown and stored server-side: "Qwen3 4B · Q4_K_M".
  String get label => '$displayName · $quantization';
}

/// How the engine runs the model. Context and output are in tokens.
class LocalRuntimeParams {
  const LocalRuntimeParams({
    required this.contextTokens,
    this.maxOutputTokens = 1024,
    this.temperature = 0.3,
    this.topK = 40,
    this.topP = 0.9,
    this.threads,
    this.backend = LocalBackend.cpu,
    this.gpuLayers = 0,
  });

  final int contextTokens;
  final int maxOutputTokens;

  /// Low by default: a report should stick to the numbers.
  final double temperature;
  final int topK;
  final double topP;

  /// Null lets the engine pick (usually the performance cores).
  final int? threads;
  final LocalBackend backend;

  /// llama.cpp only: layers offloaded to the GPU.
  final int gpuLayers;

  LocalRuntimeParams copyWith({int? maxOutputTokens, LocalBackend? backend}) =>
      LocalRuntimeParams(
        contextTokens: contextTokens,
        maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        threads: threads,
        backend: backend ?? this.backend,
        gpuLayers: gpuLayers,
      );
}

/// The runtime reported to the server with each on-device run.
class AiLocalRuntime {
  const AiLocalRuntime({
    required this.engine,
    required this.modelId,
    required this.displayName,
    required this.quantization,
    required this.backend,
    required this.contextTokens,
    required this.maxOutputTokens,
    this.appVersion,
  });

  factory AiLocalRuntime.of(
    InstalledLocalModel model,
    LocalRuntimeParams params, {
    String? appVersion,
  }) => AiLocalRuntime(
    engine: model.engine,
    modelId: model.id,
    displayName: model.displayName,
    quantization: model.quantization,
    backend: params.backend,
    contextTokens: params.contextTokens,
    maxOutputTokens: params.maxOutputTokens,
    appVersion: appVersion,
  );

  final LocalEngineKind engine;
  final String modelId;
  final String displayName;
  final String quantization;
  final LocalBackend backend;
  final int contextTokens;
  final int maxOutputTokens;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
    'engine': engine.wire,
    'model_id': modelId,
    'display_name': displayName,
    'quantization': quantization,
    'backend': backend.wire,
    'context_tokens': contextTokens,
    'max_output_tokens': maxOutputTokens,
    'app_version': ?appVersion,
  };

  static AiLocalRuntime? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final engine = LocalEngineKind.fromWire(raw['engine'] as String?);
    if (engine == null) return null;
    return AiLocalRuntime(
      engine: engine,
      modelId: raw['model_id'] as String? ?? '',
      displayName: raw['display_name'] as String? ?? '',
      quantization: raw['quantization'] as String? ?? '',
      backend: LocalBackend.fromWire(raw['backend'] as String?),
      contextTokens: raw['context_tokens'] as int? ?? 0,
      maxOutputTokens: raw['max_output_tokens'] as int? ?? 0,
      appVersion: raw['app_version'] as String?,
    );
  }
}

/// One message to feed the model.
class LocalChatMessage {
  const LocalChatMessage({required this.role, required this.content});

  /// 'user' or 'assistant'.
  final String role;
  final String content;

  static LocalChatMessage fromJson(Map<String, dynamic> json) =>
      LocalChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}

/// What the server returns for the phone to generate (a report or answer).
class AiLocalTurn {
  const AiLocalTurn({
    required this.analysisId,
    required this.messageId,
    required this.isReport,
    required this.systemPrompt,
    required this.messages,
    required this.maxOutputTokens,
    required this.deadlineAt,
  });

  final String analysisId;
  final String messageId;
  final bool isReport;
  final String systemPrompt;
  final List<LocalChatMessage> messages;
  final int maxOutputTokens;
  final DateTime deadlineAt;

  static AiLocalTurn fromJson(Map<String, dynamic> json) => AiLocalTurn(
    analysisId: json['analysis_id'] as String,
    messageId: json['message_id'] as String,
    isReport: json['kind'] == 'REPORT',
    systemPrompt: json['system_prompt'] as String,
    messages: (json['messages'] as List<dynamic>)
        .map((m) => LocalChatMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    maxOutputTokens: json['max_output_tokens'] as int? ?? 0,
    deadlineAt: DateTime.parse(json['deadline_at'] as String),
  );
}

/// What the phone generated, sent back to the server.
class AiLocalResult {
  const AiLocalResult({
    required this.content,
    required this.status,
    this.errorCode,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.truncated = false,
    this.durationMs = 0,
  });

  final String content;

  /// 'COMPLETED', 'FAILED' or 'CANCELLED'.
  final String status;
  final String? errorCode;
  final int inputTokens;
  final int outputTokens;
  final bool truncated;
  final int durationMs;

  Map<String, dynamic> toJson() => {
    'content': content,
    'status': status,
    'error_code': errorCode,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'truncated': truncated,
    'duration_ms': durationMs,
  };

  static AiLocalResult fromJson(Map<String, dynamic> json) => AiLocalResult(
    content: json['content'] as String? ?? '',
    status: json['status'] as String? ?? 'FAILED',
    errorCode: json['error_code'] as String?,
    inputTokens: json['input_tokens'] as int? ?? 0,
    outputTokens: json['output_tokens'] as int? ?? 0,
    truncated: json['truncated'] as bool? ?? false,
    durationMs: json['duration_ms'] as int? ?? 0,
  );
}
