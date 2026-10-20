import 'ai_analysis_request.dart';
import 'ai_settings.dart';
import 'local_model.dart';

DateTime? _date(Object? raw) => raw is String ? DateTime.parse(raw) : null;

/// What the preview says will be sent.
class AiDisclosure {
  const AiDisclosure({
    required this.sections,
    required this.walletCount,
    required this.transactionCount,
    required this.transactionsOmitted,
    required this.anonymized,
    required this.includesPersonalContext,
    this.profile = 'standard',
    this.compactionSteps = const [],
  });

  final Set<AiDataSection> sections;
  final int walletCount;
  final int transactionCount;
  final int transactionsOmitted;
  final bool anonymized;
  final bool includesPersonalContext;
  final String profile;

  /// Detail given up to fit the token budget, in order.
  final List<String> compactionSteps;

  static AiDisclosure fromJson(Map<String, dynamic> json) => AiDisclosure(
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map((s) => AiDataSection.fromWire(s as String))
        .whereType<AiDataSection>()
        .toSet(),
    walletCount: json['wallet_count'] as int? ?? 0,
    transactionCount: json['transaction_count'] as int? ?? 0,
    transactionsOmitted: json['transactions_omitted'] as int? ?? 0,
    anonymized: json['anonymized'] as bool? ?? false,
    includesPersonalContext:
        json['includes_personal_context'] as bool? ?? false,
    profile: json['profile'] as String? ?? 'standard',
    compactionSteps: (json['compaction_steps'] as List<dynamic>? ?? const [])
        .cast<String>(),
  );
}

/// Whether an on-device prompt and its answer fit the model's context.
class AiContextFit {
  const AiContextFit({
    required this.contextTokens,
    required this.inputTokens,
    required this.reservedOutputTokens,
    required this.fits,
  });

  final int contextTokens;
  final int inputTokens;
  final int reservedOutputTokens;
  final bool fits;

  /// Share of the context the prompt and answer take (can exceed 1).
  double get usage => (inputTokens + reservedOutputTokens) / contextTokens;

  static AiContextFit? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return AiContextFit(
      contextTokens: raw['context_tokens'] as int? ?? 1,
      inputTokens: raw['input_tokens'] as int? ?? 0,
      reservedOutputTokens: raw['reserved_output_tokens'] as int? ?? 0,
      fits: raw['fits'] as bool? ?? false,
    );
  }
}

/// The exact prompt an analysis would send.
class AiPreview {
  const AiPreview({
    required this.provider,
    required this.model,
    required this.promptVersion,
    required this.systemPrompt,
    required this.instructions,
    required this.dataBlock,
    required this.dataFingerprint,
    required this.estimatedInputTokens,
    required this.maxOutputTokens,
    this.estimatedInputCost,
    this.estimatedMaxOutputCost,
    this.periodFrom,
    required this.periodTo,
    required this.disclosure,
    this.target = AiMode.cloud,
    this.contextFit,
  });

  /// Where the run will happen; for on-device, [provider] is onDevice.
  final AiMode target;
  final AiContextFit? contextFit;
  final AiProviderKind provider;
  final String model;
  final String promptVersion;
  final String systemPrompt;
  final String instructions;
  final String dataBlock;
  final String dataFingerprint;
  final int estimatedInputTokens;
  final int maxOutputTokens;
  final double? estimatedInputCost;
  final double? estimatedMaxOutputCost;
  final DateTime? periodFrom;
  final DateTime periodTo;
  final AiDisclosure disclosure;

  /// Upper bound of the cost, when the user entered prices.
  double? get estimatedMaxCost =>
      estimatedInputCost == null && estimatedMaxOutputCost == null
      ? null
      : (estimatedInputCost ?? 0) + (estimatedMaxOutputCost ?? 0);

  static AiPreview fromJson(Map<String, dynamic> json) {
    final cost = json['estimated_cost'] as Map<String, dynamic>?;
    return AiPreview(
      provider: AiProviderKind.fromWire(json['provider'] as String),
      model: json['model'] as String,
      promptVersion: json['prompt_version'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String,
      instructions: json['instructions'] as String,
      dataBlock: json['data_block'] as String,
      dataFingerprint: json['data_fingerprint'] as String,
      estimatedInputTokens: json['estimated_input_tokens'] as int? ?? 0,
      maxOutputTokens: json['max_output_tokens'] as int? ?? 0,
      estimatedInputCost: (cost?['input_cost'] as num?)?.toDouble(),
      estimatedMaxOutputCost: (cost?['max_output_cost'] as num?)?.toDouble(),
      periodFrom: _date(json['period_from']),
      periodTo: DateTime.parse(json['period_to'] as String),
      disclosure: AiDisclosure.fromJson(
        json['disclosure'] as Map<String, dynamic>? ?? const {},
      ),
      target: AiMode.fromWire(json['target'] as String?),
      contextFit: AiContextFit.fromJson(json['context_fit']),
    );
  }
}

enum AiStatus {
  streaming('STREAMING'),
  completed('COMPLETED'),
  failed('FAILED'),
  cancelled('CANCELLED');

  const AiStatus(this.wire);

  final String wire;

  static AiStatus fromWire(String? value) => AiStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => AiStatus.failed,
  );
}

enum AiMessageKind {
  context('CONTEXT'),
  report('REPORT'),
  question('QUESTION'),
  answer('ANSWER');

  const AiMessageKind(this.wire);

  final String wire;

  static AiMessageKind fromWire(String? value) => AiMessageKind.values
      .firstWhere((k) => k.wire == value, orElse: () => AiMessageKind.answer);
}

class AiMessage {
  const AiMessage({
    required this.id,
    required this.kind,
    required this.content,
    required this.status,
    this.errorCode,
    this.model,
    this.inputTokens,
    this.outputTokens,
    this.truncated = false,
    this.createdAt,
    this.durationMs,
  });

  final String id;
  final AiMessageKind kind;
  final String content;
  final AiStatus status;
  final String? errorCode;
  final String? model;
  final int? inputTokens;
  final int? outputTokens;
  final bool truncated;
  final DateTime? createdAt;

  /// How long the phone took (on-device only).
  final int? durationMs;

  bool get fromUser =>
      kind == AiMessageKind.question || kind == AiMessageKind.context;

  AiMessage copyWith({
    String? content,
    AiStatus? status,
    String? errorCode,
    int? inputTokens,
    int? outputTokens,
    bool? truncated,
  }) => AiMessage(
    id: id,
    kind: kind,
    content: content ?? this.content,
    status: status ?? this.status,
    errorCode: errorCode ?? this.errorCode,
    model: model,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    truncated: truncated ?? this.truncated,
    createdAt: createdAt,
    durationMs: durationMs,
  );

  static AiMessage fromJson(Map<String, dynamic> json) => AiMessage(
    id: json['id'] as String,
    kind: AiMessageKind.fromWire(json['kind'] as String?),
    content: json['content'] as String? ?? '',
    status: AiStatus.fromWire(json['status'] as String?),
    errorCode: json['error_code'] as String?,
    model: json['model'] as String?,
    inputTokens: json['input_tokens'] as int?,
    outputTokens: json['output_tokens'] as int?,
    truncated: json['truncated'] as bool? ?? false,
    createdAt: _date(json['created_at']),
    durationMs: json['duration_ms'] as int?,
  );
}

class AiAnalysisSummary {
  const AiAnalysisSummary({
    required this.id,
    required this.title,
    required this.preset,
    this.periodFrom,
    required this.periodTo,
    required this.status,
    this.errorCode,
    required this.provider,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.cost,
    required this.createdAt,
    this.runtime,
  });

  final String id;
  final String title;
  final String preset;
  final DateTime? periodFrom;
  final DateTime periodTo;
  final AiStatus status;
  final String? errorCode;
  final AiProviderKind provider;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double? cost;
  final DateTime createdAt;

  /// How an on-device analysis ran; null for cloud ones.
  final AiLocalRuntime? runtime;

  bool get isOnDevice => provider == AiProviderKind.onDevice;

  static AiAnalysisSummary fromJson(Map<String, dynamic> json) =>
      AiAnalysisSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        preset: json['preset'] as String,
        periodFrom: _date(json['period_from']),
        periodTo: DateTime.parse(json['period_to'] as String),
        status: AiStatus.fromWire(json['status'] as String?),
        errorCode: json['error_code'] as String?,
        provider: AiProviderKind.fromWire(json['provider'] as String),
        model: json['model'] as String,
        inputTokens: json['input_tokens'] as int? ?? 0,
        outputTokens: json['output_tokens'] as int? ?? 0,
        cost: (json['cost'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        runtime: AiLocalRuntime.fromJson(json['runtime']),
      );
}

class AiAnalysisDetail {
  const AiAnalysisDetail({
    required this.summary,
    required this.systemPrompt,
    required this.messages,
    required this.followUpsLeft,
    required this.canAskFollowUps,
  });

  final AiAnalysisSummary summary;
  final String systemPrompt;
  final List<AiMessage> messages;
  final int followUpsLeft;
  final bool canAskFollowUps;

  /// The first message: instructions and data exactly as sent.
  AiMessage? get contextMessage {
    for (final m in messages) {
      if (m.kind == AiMessageKind.context) return m;
    }
    return null;
  }

  static AiAnalysisDetail fromJson(Map<String, dynamic> json) =>
      AiAnalysisDetail(
        summary: AiAnalysisSummary.fromJson(json),
        systemPrompt: json['system_prompt'] as String? ?? '',
        messages: (json['messages'] as List<dynamic>? ?? const [])
            .map((m) => AiMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        followUpsLeft: json['follow_ups_left'] as int? ?? 0,
        canAskFollowUps: json['can_ask_follow_ups'] as bool? ?? false,
      );
}

class AiHistoryPage {
  const AiHistoryPage({required this.items, this.nextCursor});

  final List<AiAnalysisSummary> items;
  final String? nextCursor;

  static AiHistoryPage fromJson(Map<String, dynamic> json) => AiHistoryPage(
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((i) => AiAnalysisSummary.fromJson(i as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
  );
}
