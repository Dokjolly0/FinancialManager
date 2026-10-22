import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_error.dart';
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
    bool clearErrors = false,
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
      state = state.copyWith(
        detail: detail,
        messages: detail.messages
            .where((m) => m.kind != AiMessageKind.context)
            .toList(),
        isLoading: false,
      );
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
    _cancelToken?.cancel('stopped by user');
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
    state = state.copyWith(isStreaming: false);
    _subscription = null;
    _cancelToken = null;
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
