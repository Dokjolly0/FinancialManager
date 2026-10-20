import '../../../../core/api/sse.dart';
import 'ai_analysis.dart';

/// The events of an analysis or follow-up stream (plan.md section 32.4):
/// meta, then deltas, then usage or error, then done.
sealed class AiStreamEvent {
  const AiStreamEvent();

  /// Maps a raw event; unknown event names are ignored (null) so a newer
  /// backend can add events without breaking older apps.
  static AiStreamEvent? fromSse(SseEvent e) {
    final json = e.json;
    return switch (e.event) {
      'meta' => AiStreamMeta(
        analysisId: json['analysis_id'] as String,
        messageId: json['message_id'] as String,
        kind: AiMessageKind.fromWire(json['kind'] as String?),
      ),
      'delta' => AiStreamDelta(json['text'] as String? ?? ''),
      'usage' => AiStreamUsage(
        inputTokens: json['input_tokens'] as int? ?? 0,
        outputTokens: json['output_tokens'] as int? ?? 0,
        truncated: json['truncated'] as bool? ?? false,
      ),
      'error' => AiStreamError(
        code: json['code'] as String? ?? 'AI_PROVIDER_ERROR',
        message: json['message'] as String? ?? '',
      ),
      'done' => AiStreamDone(AiStatus.fromWire(json['status'] as String?)),
      _ => null,
    };
  }
}

final class AiStreamMeta extends AiStreamEvent {
  const AiStreamMeta({
    required this.analysisId,
    required this.messageId,
    required this.kind,
  });

  final String analysisId;
  final String messageId;
  final AiMessageKind kind;
}

final class AiStreamDelta extends AiStreamEvent {
  const AiStreamDelta(this.text);

  final String text;
}

final class AiStreamUsage extends AiStreamEvent {
  const AiStreamUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.truncated,
  });

  final int inputTokens;
  final int outputTokens;
  final bool truncated;
}

/// A failure after the stream started; [message] is the provider's own
/// explanation.
final class AiStreamError extends AiStreamEvent {
  const AiStreamError({required this.code, required this.message});

  final String code;
  final String message;
}

final class AiStreamDone extends AiStreamEvent {
  const AiStreamDone(this.status);

  final AiStatus status;
}
