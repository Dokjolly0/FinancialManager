import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_error.dart';
import '../../data/local/local_ai_runner.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/ai_stream_event.dart';
import '../../domain/repositories/ai_repository.dart';

/// Family key of a conversation that is about to be created by a run.
const aiNewRunKey = 'new';

class AiConversationState {
  const AiConversationState({
    this.analysisId,
    this.detail,
    this.messages = const [],
    this.isLoading = false,
    this.loadError,
    this.isStreaming = false,
    this.streamErrorCode,
    this.streamErrorMessage,
    this.requestError,
    this.liveTool,
  });

  final String? analysisId;
  final AiAnalysisDetail? detail;

  /// Messages shown, including the one being streamed.
  final List<AiMessage> messages;
  final bool isLoading;
  final AppError? loadError;
  final bool isStreaming;

  /// A failure reported by the stream (provider error, timeout).
  final String? streamErrorCode;
  final String? streamErrorMessage;

  /// A refusal before streaming started (consent, data changed, limits).
  final AppError? requestError;

  /// What the model is looking up right now (chats, section 34.7).
  final AiStreamTool? liveTool;

  bool get canAsk => !isStreaming && (detail?.canAskFollowUps ?? false);

  AiConversationState copyWith({
    String? analysisId,
    AiAnalysisDetail? detail,
    List<AiMessage>? messages,
    bool? isLoading,
    AppError? loadError,
    bool? isStreaming,
    String? streamErrorCode,
    String? streamErrorMessage,
    AppError? requestError,
    AiStreamTool? liveTool,
    bool clearErrors = false,
    bool clearLiveTool = false,
  }) => AiConversationState(
    analysisId: analysisId ?? this.analysisId,
    detail: detail ?? this.detail,
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    loadError: clearErrors ? null : (loadError ?? this.loadError),
    isStreaming: isStreaming ?? this.isStreaming,
    streamErrorCode: clearErrors
        ? null
        : (streamErrorCode ?? this.streamErrorCode),
    streamErrorMessage: clearErrors
        ? null
        : (streamErrorMessage ?? this.streamErrorMessage),
    requestError: clearErrors ? null : (requestError ?? this.requestError),
    liveTool: clearLiveTool ? null : (liveTool ?? this.liveTool),
  );
}

/// One analysis conversation: loads it, runs it (for [aiNewRunKey]),
/// streams follow-up answers and stops a stream on request. Leaving the
/// screen disposes the controller, which closes the connection; the server
/// then cancels the model call and keeps the partial text.
class AiConversationController extends Notifier<AiConversationState> {
  AiConversationController(this.arg);

  final String arg;
  CancelToken? _cancelToken;
  StreamSubscription<AiStreamEvent>? _subscription;
  bool _stopRequested = false;

  /// Held while a turn goes on with the screen gone ("continue in
  /// background"): the provider is auto-disposed otherwise.
  KeepAliveLink? _keepAlive;

  /// Following a turn the phone is writing for a screen opened after it
  /// started (from the history or a notification).
  LocalAiRunner? _following;
  VoidCallback? _onLive;

  AiRepository get _repo => ref.read(aiRepositoryProvider);

  /// Follow-ups continue where the report was written.
  AiTurnSource get _followUpSource => ref.read(
    aiTurnSourceProvider(
      state.detail?.summary.isOnDevice == true ? AiMode.onDevice : AiMode.cloud,
    ),
  );

  @override
  AiConversationState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _cancelToken?.cancel('disposed');
      _unfollow();
    });
    if (arg == aiNewRunKey) return const AiConversationState();
    Future.microtask(load);
    return AiConversationState(analysisId: arg, isLoading: true);
  }

  Future<void> load() async {
    final id = state.analysisId;
    if (id == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final detail = await _repo.getAnalysis(id);
      if (!ref.mounted) return;
      state = state.copyWith(
        detail: detail,
        messages: detail.messages
            .where((m) => m.kind != AiMessageKind.context)
            .toList(),
        isLoading: false,
      );
      if (detail.summary.isOnDevice && !state.isStreaming) _follow(id);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, loadError: e);
    }
  }

  /// Runs a previewed analysis. [clientRequestId] defaults to a new id; a
  /// retry after a network failure should reuse it.
  void startRun(
    AiAnalysisRequest request,
    String fingerprint, {
    AiMode target = AiMode.cloud,
    String? clientRequestId,
  }) {
    if (state.isStreaming) return;
    _stream(
      (token) => ref
          .read(aiTurnSourceProvider(target))
          .runAnalysis(
            request,
            dataFingerprint: fingerprint,
            clientRequestId: clientRequestId ?? const Uuid().v4(),
            cancelToken: token,
          ),
      question: null,
    );
  }

  /// Asks a follow-up question on the loaded analysis.
  void ask(String question) {
    final id = state.analysisId;
    final text = question.trim();
    if (id == null || text.isEmpty || !state.canAsk) return;
    _stream(
      (token) => _followUpSource.askFollowUp(
        id,
        text,
        cancelToken: token,
        localModelId: state.detail?.summary.runtime?.modelId,
      ),
      question: text,
    );
  }

  /// Stops the current stream; what was written so far is kept.
  void stop() {
    if (!state.isStreaming) return;
    _stopRequested = true;
    if (_following != null) {
      unawaited(_following!.cancelActive());
      return;
    }
    _cancelToken?.cancel('stopped by user');
  }

  /// Lets an on-device turn go on after the screen is left (plan.md
  /// section 33.9): this controller stays alive until the turn ends, and
  /// the phone notifies when it is done.
  void continueInBackground() {
    if (!state.isStreaming) return;
    _keepAlive ??= ref.keepAlive();
  }

  /// Shows the text of a turn the phone is writing for this analysis, if
  /// any, and reloads the stored analysis when it ends.
  void _follow(String analysisId) {
    final runner = ref.read(localAiRunnerProvider);
    final live = runner.live.value;
    if (live == null || live.analysisId != analysisId) return;
    final messageId = live.messageId;
    if (!state.messages.any((m) => m.id == messageId)) return;
    _following = runner;
    void onLive() {
      final now = runner.live.value;
      if (now == null || now.messageId != messageId) {
        _unfollow();
        state = state.copyWith(isStreaming: false);
        unawaited(load());
        return;
      }
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            m.id == messageId ? m.copyWith(content: now.text) : m,
        ],
      );
    }

    _onLive = onLive;
    runner.live.addListener(onLive);
    state = state.copyWith(isStreaming: true);
    onLive();
  }

  void _unfollow() {
    final runner = _following;
    final listener = _onLive;
    if (runner != null && listener != null) {
      runner.live.removeListener(listener);
    }
    _following = null;
    _onLive = null;
  }

  void _stream(
    Stream<AiStreamEvent> Function(CancelToken) open, {
    required String? question,
  }) {
    _stopRequested = false;
    final token = CancelToken();
    _cancelToken = token;
    final pending = <AiMessage>[
      if (question != null)
        AiMessage(
          id: 'pending-question',
          kind: AiMessageKind.question,
          content: question,
          status: AiStatus.completed,
        ),
      AiMessage(
        id: 'pending-answer',
        kind: question == null ? AiMessageKind.report : AiMessageKind.answer,
        content: '',
        status: AiStatus.streaming,
      ),
    ];
    final before = state.messages;
    state = state.copyWith(
      messages: [...before, ...pending],
      isStreaming: true,
      clearErrors: true,
    );

    _subscription = open(token).listen(
      _onEvent,
      onError: (Object error) {
        if (_stopRequested) {
          _finish(AiStatus.cancelled);
          return;
        }
        final appError = error is AppError ? error : UnknownError(cause: error);
        final streamed =
            state.messages.isNotEmpty && state.messages.last.content.isNotEmpty;
        state = streamed
            // The connection broke mid-stream: keep what arrived.
            ? state.copyWith(requestError: appError)
            // Refused before streaming: drop the placeholders.
            : state.copyWith(
                messages: before,
                isStreaming: false,
                requestError: appError,
              );
        if (streamed) _finish(AiStatus.failed);
      },
      onDone: () {
        if (state.isStreaming) {
          _finish(_stopRequested ? AiStatus.cancelled : AiStatus.completed);
        }
      },
      cancelOnError: true,
    );
  }

  void _updateLast(AiMessage Function(AiMessage) update) {
    final messages = [...state.messages];
    if (messages.isEmpty) return;
    messages[messages.length - 1] = update(messages.last);
    state = state.copyWith(messages: messages);
  }

  void _onEvent(AiStreamEvent event) {
    switch (event) {
      case AiStreamMeta(:final analysisId):
        state = state.copyWith(analysisId: analysisId);
      case AiStreamDelta(:final text):
        _updateLast((m) => m.copyWith(content: m.content + text));
      case AiStreamTool():
        state = state.copyWith(liveTool: event);
      case AiStreamUsage(
        :final inputTokens,
        :final outputTokens,
        :final truncated,
      ):
        _updateLast(
          (m) => m.copyWith(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            truncated: truncated,
          ),
        );
      case AiStreamError(:final code, :final message):
        state = state.copyWith(
          streamErrorCode: code,
          streamErrorMessage: message,
        );
      case AiStreamDone(:final status):
        _finish(status);
    }
  }

  void _finish(AiStatus status) {
    if (!state.isStreaming) return;
    _updateLast(
      (m) => m.copyWith(status: status, errorCode: state.streamErrorCode),
    );
    state = state.copyWith(isStreaming: false, clearLiveTool: true);
    _subscription = null;
    _cancelToken = null;
    _keepAlive?.close();
    _keepAlive = null;
    // A new analysis changes the setup checklist; the stored detail has
    // the real ids, follow-ups left and token totals.
    ref.invalidate(aiSettingsProvider);
    if (state.analysisId != null) unawaited(load());
  }
}

final aiConversationControllerProvider = NotifierProvider.autoDispose
    .family<AiConversationController, AiConversationState, String>(
      AiConversationController.new,
    );
