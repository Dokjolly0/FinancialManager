import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/errors/app_error.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/ai_stream_event.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_prompt_preview_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_conversation_controller.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_draft_controller.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

AiAnalysisDetail _detail({bool canAsk = true, List<AiMessage>? messages}) =>
    AiAnalysisDetail(
      summary: AiAnalysisSummary(
        id: 'a1',
        title: 'Check-up',
        preset: 'MONTHLY_CHECKUP',
        periodTo: DateTime(2026, 10, 20),
        status: AiStatus.completed,
        provider: AiProviderKind.openai,
        model: 'gpt-test',
        inputTokens: 10,
        outputTokens: 5,
        createdAt: DateTime(2026, 10, 20),
      ),
      systemPrompt: 'sys',
      messages:
          messages ??
          const [
            AiMessage(
              id: 'm1',
              kind: AiMessageKind.context,
              content: 'dati',
              status: AiStatus.completed,
            ),
            AiMessage(
              id: 'm2',
              kind: AiMessageKind.report,
              content: 'Report',
              status: AiStatus.completed,
            ),
          ],
      followUpsLeft: canAsk ? 20 : 0,
      canAskFollowUps: canAsk,
    );

final _preview = AiPreview.fromJson({
  'provider': 'openai',
  'model': 'gpt-test',
  'system_prompt': 'REGOLE DI SISTEMA',
  'instructions': 'Istruzioni predefinite',
  'data_block': '<financial_data>DATI</financial_data>',
  'data_fingerprint': 'f' * 64,
  'estimated_input_tokens': 1200,
  'max_output_tokens': 4096,
  'period_to': '2026-10-20',
  'disclosure': {
    'sections': ['monthly'],
    'wallet_count': 1,
  },
});

class _FakeRepo implements AiRepository {
  StreamController<AiStreamEvent>? controller;
  CancelToken? lastToken;
  String? lastQuestion;
  AppError? refuse;
  AiAnalysisDetail detail = _detail();
  int previewCalls = 0;

  Stream<AiStreamEvent> _open(CancelToken? token) {
    lastToken = token;
    if (refuse != null) return Stream.error(refuse!);
    controller = StreamController<AiStreamEvent>();
    token?.whenCancel.then((_) {
      controller?.addError(const UnknownError());
      controller?.close();
    });
    return controller!.stream;
  }

  @override
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _open(cancelToken);

  @override
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  }) {
    lastQuestion = question;
    return _open(cancelToken);
  }

  @override
  Future<AiAnalysisDetail> getAnalysis(String id) async => detail;

  @override
  Future<AiPreview> preview(AiAnalysisRequest request) async {
    previewCalls++;
    if (refuse != null) throw refuse!;
    return _preview;
  }

  @override
  Future<AiSettings> getSettings() async => const AiSettings(
    available: true,
    consent: AiConsent(currentVersion: 1, required: false),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(repo)],
    );
  });
  tearDown(() => container.dispose());

  AiConversationState watch(String key) {
    container.listen(aiConversationControllerProvider(key), (_, _) {});
    return container.read(aiConversationControllerProvider(key));
  }

  test('a run appends deltas, then loads the stored analysis', () async {
    watch(aiNewRunKey);
    final notifier = container.read(
      aiConversationControllerProvider(aiNewRunKey).notifier,
    );
    notifier.startRun(const AiAnalysisRequest(preset: 'SAVINGS'), 'f' * 64);
    expect(
      container.read(aiConversationControllerProvider(aiNewRunKey)).isStreaming,
      isTrue,
    );

    repo.controller!
      ..add(
        const AiStreamMeta(
          analysisId: 'a1',
          messageId: 'm2',
          kind: AiMessageKind.report,
        ),
      )
      ..add(const AiStreamDelta('Ciao '))
      ..add(const AiStreamDelta('mondo'));
    await _flush();
    var state = container.read(aiConversationControllerProvider(aiNewRunKey));
    expect(state.analysisId, 'a1');
    expect(state.messages.last.content, 'Ciao mondo');
    expect(state.canAsk, isFalse, reason: 'no follow-ups while streaming');

    repo.controller!
      ..add(
        const AiStreamUsage(inputTokens: 10, outputTokens: 5, truncated: false),
      )
      ..add(const AiStreamDone(AiStatus.completed));
    await repo.controller!.close();
    await _flush();
    await _flush();
    state = container.read(aiConversationControllerProvider(aiNewRunKey));
    expect(state.isStreaming, isFalse);
    expect(state.detail, isNotNull, reason: 'reloaded after done');
    expect(state.messages.map((m) => m.kind), [
      AiMessageKind.report,
    ], reason: 'the CONTEXT message is hidden');
    expect(state.canAsk, isTrue);
  });

  test('stop cancels the request and marks the answer cancelled', () async {
    watch(aiNewRunKey);
    final notifier = container.read(
      aiConversationControllerProvider(aiNewRunKey).notifier,
    );
    notifier.startRun(const AiAnalysisRequest(preset: 'SAVINGS'), 'f' * 64);
    repo.controller!.add(const AiStreamDelta('parziale'));
    await _flush();

    notifier.stop();
    await _flush();
    expect(repo.lastToken!.isCancelled, isTrue);
    final state = container.read(aiConversationControllerProvider(aiNewRunKey));
    expect(state.isStreaming, isFalse);
    expect(state.messages.last.status, AiStatus.cancelled);
    expect(state.messages.last.content, 'parziale');
    expect(state.requestError, isNull, reason: 'stopping is not an error');
  });

  test('an error event is kept for the screen', () async {
    watch(aiNewRunKey);
    container
        .read(aiConversationControllerProvider(aiNewRunKey).notifier)
        .startRun(const AiAnalysisRequest(preset: 'SAVINGS'), 'f' * 64);
    repo.controller!
      ..add(
        const AiStreamError(
          code: 'AI_PROVIDER_UNAVAILABLE',
          message: 'Overloaded',
        ),
      )
      ..add(const AiStreamDone(AiStatus.failed));
    await _flush();
    final state = container.read(aiConversationControllerProvider(aiNewRunKey));
    expect(state.streamErrorCode, 'AI_PROVIDER_UNAVAILABLE');
    expect(state.streamErrorMessage, 'Overloaded');
    expect(state.messages.last.status, AiStatus.failed);
  });

  test('a refusal before streaming drops the placeholders', () async {
    repo.refuse = const DomainError(
      code: 'AI_DATA_CHANGED',
      message: 'changed',
    );
    watch(aiNewRunKey);
    container
        .read(aiConversationControllerProvider(aiNewRunKey).notifier)
        .startRun(const AiAnalysisRequest(preset: 'SAVINGS'), 'f' * 64);
    await _flush();
    final state = container.read(aiConversationControllerProvider(aiNewRunKey));
    expect(state.messages, isEmpty);
    expect(state.isStreaming, isFalse);
    expect((state.requestError! as DomainError).code, 'AI_DATA_CHANGED');
  });

  test('follow-ups need a loaded analysis that allows them', () async {
    watch('a1');
    await _flush();
    final notifier = container.read(
      aiConversationControllerProvider('a1').notifier,
    );
    notifier.ask('  Perché?  ');
    expect(repo.lastQuestion, 'Perché?');
    final state = container.read(aiConversationControllerProvider('a1'));
    expect(state.messages.map((m) => m.kind), [
      AiMessageKind.report,
      AiMessageKind.question,
      AiMessageKind.answer,
    ]);

    // While streaming, a second question is ignored.
    repo.lastQuestion = null;
    notifier.ask('Altro');
    expect(repo.lastQuestion, isNull);
  });

  test('no follow-ups when the analysis does not allow them', () async {
    repo.detail = _detail(canAsk: false);
    watch('a1');
    await _flush();
    container
        .read(aiConversationControllerProvider('a1').notifier)
        .ask('Perché?');
    expect(repo.lastQuestion, isNull);
  });

  test(
    'the draft keeps edited instructions when the preview is refreshed',
    () async {
      final draft = container.read(aiDraftControllerProvider.notifier);
      expect(
        await draft.preview(const AiAnalysisRequest(preset: 'SAVINGS')),
        isTrue,
      );
      draft.setInstructions('Le mie istruzioni');
      expect(await draft.refresh(instructions: 'Le mie istruzioni'), isTrue);
      expect(
        container.read(aiDraftControllerProvider).request!.instructions,
        'Le mie istruzioni',
      );
      expect(repo.previewCalls, 2);

      repo.refuse = const DomainError(
        code: 'AI_CONSENT_REQUIRED',
        message: 'consent',
      );
      expect(
        await draft.preview(const AiAnalysisRequest(preset: 'SAVINGS')),
        isFalse,
      );
      expect(
        container.read(aiDraftControllerProvider).error,
        isA<DomainError>(),
      );
    },
  );

  testWidgets('the preview lets the user edit only the instructions', (
    tester,
  ) async {
    final widgetContainer = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(widgetContainer.dispose);
    await widgetContainer
        .read(aiDraftControllerProvider.notifier)
        .preview(const AiAnalysisRequest(preset: 'SAVINGS'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: widgetContainer,
        child: const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiPromptPreviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editable = find.byType(TextField);
    expect(
      editable,
      findsOneWidget,
      reason: 'only the instructions are editable',
    );
    expect(find.text('Istruzioni predefinite'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Dati inviati'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Dati inviati'));
    await tester.pumpAndSettle();
    final data = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.data == '<financial_data>DATI</financial_data>',
      ),
    );
    expect(data, isNotNull);

    await tester.enterText(editable, 'Nuove istruzioni');
    await tester.tap(find.text('Ripristina'));
    await tester.pump();
    expect(find.text('Istruzioni predefinite'), findsOneWidget);
  });
}
