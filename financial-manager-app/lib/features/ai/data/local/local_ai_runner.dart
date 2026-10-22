import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/errors/app_error.dart';
import '../../domain/local/local_llm_engine.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_stream_event.dart';
import '../../domain/models/local_model.dart';
import '../../domain/repositories/ai_repository.dart';
import 'local_result_outbox.dart';

/// Matches the server's limit on a stored answer.
const localMaxAnswerBytes = 200 * 1024;

/// Runs reports and follow-up answers on the phone (plan.md section 33).
///
/// Same events as a cloud run, so the conversation controller doesn't care
/// where the text comes from: the server prepares the turn (meta), the
/// engine streams deltas, the result is submitted (to the outbox when
/// offline), then usage or error, then done.
class LocalAiRunner implements AiTurnSource {
  LocalAiRunner({
    required AiRepository repo,
    required LocalModelHost host,
    required LocalResultOutbox outbox,
    required String? Function() currentUserId,
    String? Function()? currentUserName,
    DateTime Function()? now,
    String? appVersion,
  }) : _repo = repo,
       _host = host,
       _outbox = outbox,
       _currentUserId = currentUserId,
       _currentUserName = currentUserName ?? (() => null),
       _now = now ?? DateTime.now,
       _appVersion = appVersion;

  final AiRepository _repo;
  final LocalModelHost _host;
  final LocalResultOutbox _outbox;
  final String? Function() _currentUserId;
  final String? Function() _currentUserName;
  final DateTime Function() _now;
  final String? _appVersion;

  @override
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _turn(
    (session) => _repo.prepareLocalAnalysis(
      request,
      dataFingerprint: dataFingerprint,
      clientRequestId: clientRequestId,
      runtime: AiLocalRuntime.of(
        session.model,
        session.params,
        appVersion: _appVersion,
      ),
    ),
    cancelToken,
  );

  @override
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  }) => _turn(
    (_) => _repo.prepareLocalFollowUp(analysisId, question),
    cancelToken,
    modelId: localModelId,
  );

  Stream<AiStreamEvent> _turn(
    Future<AiLocalTurn> Function(LocalSession) prepare,
    CancelToken? cancelToken, {
    String? modelId,
  }) {
    final out = StreamController<AiStreamEvent>();
    out.onListen = () => _run(out, prepare, cancelToken, modelId);
    return out.stream;
  }

  Future<void> _run(
    StreamController<AiStreamEvent> out,
    Future<AiLocalTurn> Function(LocalSession) prepare,
    CancelToken? cancelToken,
    String? modelId,
  ) async {
    final LocalSession session;
    final AiLocalTurn turn;
    // Earlier results that couldn't be sent go first, best effort.
    final userId = _currentUserId();
    if (userId != null) unawaited(_outbox.flush(_repo, userId));
    try {
      session = await _host.acquire(modelId: modelId);
      turn = await prepare(session);
    } on LocalEngineException catch (e) {
      out.addError(DomainError(code: e.code, message: e.message ?? e.code));
      await out.close();
      return;
    } on AppError catch (e) {
      out.addError(e);
      await out.close();
      return;
    }
    out.add(
      AiStreamMeta(
        analysisId: turn.analysisId,
        messageId: turn.messageId,
        kind: turn.isReport ? AiMessageKind.report : AiMessageKind.answer,
      ),
    );

    final started = _now();
    final text = StringBuffer();
    var bytes = 0;
    var tooLong = false;
    var cancelled = false;
    String? errorCode;
    String? errorMessage;
    LocalGenStats? stats;

    final engine = session.engine;
    final params = session.params.copyWith(
      maxOutputTokens: turn.maxOutputTokens > 0
          ? turn.maxOutputTokens
          : session.params.maxOutputTokens,
    );
    unawaited(
      cancelToken?.whenCancel.then((_) {
        cancelled = true;
        return engine.cancel();
      }),
    );
    // The screen went away without stopping: stop the engine too. The
    // partial text is still submitted below.
    out.onCancel = () {
      cancelled = true;
      return engine.cancel();
    };
    final timeLeft =
        turn.deadlineAt.difference(_now()) - const Duration(minutes: 2);
    final deadline = Timer(timeLeft.isNegative ? Duration.zero : timeLeft, () {
      errorCode = LocalErrorCodes.timeout;
      unawaited(engine.cancel());
    });

    try {
      final messages = await _fitHistory(
        session,
        turn.systemPrompt,
        turn.messages,
        params,
      );
      await for (final event in engine.generate(
        LocalChatRequest(
          system: turn.systemPrompt,
          messages: messages,
          params: params,
        ),
      )) {
        switch (event) {
          case LocalGenDelta(text: final piece):
            final size = piece.length * 3; // worst case UTF-8, cheap bound
            if (bytes + size > localMaxAnswerBytes) {
              tooLong = true;
              unawaited(engine.cancel());
              break;
            }
            bytes += size;
            text.write(piece);
            if (out.hasListener) out.add(AiStreamDelta(piece));
          case LocalGenStats():
            stats = event;
        }
      }
    } on LocalEngineException catch (e) {
      errorCode = e.code;
      errorMessage = e.message;
    } catch (e) {
      errorCode = LocalErrorCodes.engine;
      errorMessage = e.toString();
    } finally {
      deadline.cancel();
    }

    final status = errorCode != null
        ? AiStatus.failed
        : cancelled
        ? AiStatus.cancelled
        : AiStatus.completed;
    final result = AiLocalResult(
      content: text.toString(),
      status: status.wire,
      errorCode: errorCode,
      inputTokens: stats?.promptTokens ?? 0,
      outputTokens: stats?.outputTokens ?? 0,
      truncated: tooLong || (stats?.truncated ?? false),
      durationMs: _now().difference(started).inMilliseconds,
    );
    final finalStats = stats;
    if (finalStats != null && status == AiStatus.completed) {
      _host.recordSpeed(session, finalStats);
    }

    // The text exists only on this phone until the server has it.
    try {
      await _repo.submitLocalResult(turn.analysisId, turn.messageId, result);
    } on DomainError {
      // Refused for good (deleted meanwhile, already saved): nothing to retry.
    } catch (_) {
      final userId = _currentUserId();
      if (userId != null) {
        await _outbox.add(
          PendingLocalResult(
            userId: userId,
            analysisId: turn.analysisId,
            messageId: turn.messageId,
            result: result,
            createdAt: _now(),
            ownerName: _currentUserName(),
            modelLabel: session.model.label,
            isReport: turn.isReport,
          ),
        );
      }
    }

    if (out.hasListener) {
      if (errorCode != null) {
        out.add(AiStreamError(code: errorCode!, message: errorMessage ?? ''));
      } else {
        out.add(
          AiStreamUsage(
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens,
            truncated: result.truncated,
          ),
        );
      }
      out.add(AiStreamDone(status));
    }
    await out.close();
  }

  /// Drops the oldest question/answer pairs until the conversation and the
  /// answer fit the context. The data message and the report are never
  /// dropped: without them a follow-up has nothing to stand on.
  Future<List<LocalChatMessage>> _fitHistory(
    LocalSession session,
    String system,
    List<LocalChatMessage> messages,
    LocalRuntimeParams params,
  ) async {
    final budget = params.contextTokens - params.maxOutputTokens;
    var current = List.of(messages);
    while (true) {
      final tokens = await _count(session.engine, [
        system,
        ...current.map((m) => m.content),
      ]);
      if (tokens <= budget) return current;
      // [0] data, [1] report, then Q/A pairs, then the new question last.
      if (current.length <= 3) {
        throw const LocalEngineException(LocalErrorCodes.contextTooLong);
      }
      current = [current[0], current[1], ...current.sublist(4)];
    }
  }

  Future<int> _count(LocalLlmEngine engine, List<String> texts) async {
    final joined = texts.join('\n');
    final exact = await engine.countTokens(joined);
    // Same rough estimate as the server's when the engine can't count.
    return exact ?? (joined.length / 3.5).ceil();
  }
}
