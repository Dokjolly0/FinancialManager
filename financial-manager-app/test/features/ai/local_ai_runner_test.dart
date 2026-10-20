import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/errors/app_error.dart';
import 'package:financialmanager/features/ai/data/local/local_ai_runner.dart';
import 'package:financialmanager/features/ai/data/local/local_result_outbox.dart';
import 'package:financialmanager/features/ai/domain/local/local_llm_engine.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_stream_event.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';

import 'fakes/fake_local_engine.dart';

class _FakeRepo implements AiRepository {
  AiLocalRuntime? runtime;
  String? fingerprint;
  final submitted = <(String, String, AiLocalResult)>[];
  Object? submitError;
  AppError? prepareError;
  List<LocalChatMessage> followUpMessages = const [
    LocalChatMessage(role: 'user', content: 'dati'),
    LocalChatMessage(role: 'assistant', content: 'report'),
    LocalChatMessage(role: 'user', content: 'domanda'),
  ];

  AiLocalTurn _turn({bool report = true, List<LocalChatMessage>? messages}) =>
      AiLocalTurn(
        analysisId: 'a1',
        messageId: report ? 'm-report' : 'm-answer',
        isReport: report,
        systemPrompt: 'REGOLE',
        messages:
            messages ?? const [LocalChatMessage(role: 'user', content: 'dati')],
        maxOutputTokens: 256,
        deadlineAt: DateTime.now().add(const Duration(minutes: 30)),
      );

  @override
  Future<AiLocalTurn> prepareLocalAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    required AiLocalRuntime runtime,
  }) async {
    if (prepareError != null) throw prepareError!;
    this.runtime = runtime;
    fingerprint = dataFingerprint;
    return _turn();
  }

  @override
  Future<AiLocalTurn> prepareLocalFollowUp(
    String analysisId,
    String question,
  ) async => _turn(report: false, messages: followUpMessages);

  @override
  Future<AiMessage> submitLocalResult(
    String analysisId,
    String messageId,
    AiLocalResult result,
  ) async {
    if (submitError != null) throw submitError!;
    submitted.add((analysisId, messageId, result));
    return AiMessage(
      id: messageId,
      kind: AiMessageKind.report,
      content: result.content,
      status: AiStatus.completed,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late _FakeRepo repo;
  late FakeLocalEngine engine;
  late FakeModelHost host;
  late MemoryLocalResultOutbox outbox;

  LocalAiRunner runner({FakeModelHost? h}) => LocalAiRunner(
    repo: repo,
    host: h ?? host,
    outbox: outbox,
    currentUserId: () => 'u1',
    appVersion: '1.4.0',
  );

  setUp(() {
    repo = _FakeRepo();
    engine = FakeLocalEngine();
    host = FakeModelHost(engine);
    outbox = MemoryLocalResultOutbox();
  });

  Stream<AiStreamEvent> run({CancelToken? token, LocalAiRunner? r}) =>
      (r ?? runner()).runAnalysis(
        const AiAnalysisRequest(preset: 'SAVINGS'),
        dataFingerprint: 'f' * 64,
        clientRequestId: 'req-1',
        cancelToken: token,
      );

  test('a report streams like a cloud run and is submitted', () async {
    final events = await run().toList();
    expect(events.map((e) => e.runtimeType.toString()), [
      'AiStreamMeta',
      'AiStreamDelta',
      'AiStreamDelta',
      'AiStreamUsage',
      'AiStreamDone',
    ]);
    expect((events.last as AiStreamDone).status, AiStatus.completed);
    expect(repo.fingerprint, 'f' * 64);
    expect(repo.runtime!.toJson(), containsPair('model_id', 'qwen3-4b-q4_k_m'));
    expect(repo.runtime!.appVersion, '1.4.0');

    final (analysisId, messageId, result) = repo.submitted.single;
    expect((analysisId, messageId), ('a1', 'm-report'));
    expect(result.content, 'Ciao mondo');
    expect(result.status, 'COMPLETED');
    expect(result.inputTokens, 100);
    expect(engine.lastRequest!.system, 'REGOLE');
    expect(
      engine.lastRequest!.params.maxOutputTokens,
      256,
      reason: 'the server decides the output budget',
    );
    expect(host.speeds, hasLength(1));
  });

  test('stop cancels the engine and keeps the partial text', () async {
    engine
      ..deltas = ['uno ', 'due ', 'tre ', 'quattro']
      ..delay = const Duration(milliseconds: 30);
    final token = CancelToken();
    final events = <AiStreamEvent>[];
    await for (final e in run(token: token)) {
      events.add(e);
      if (e is AiStreamDelta) token.cancel();
    }
    expect((events.last as AiStreamDone).status, AiStatus.cancelled);
    final result = repo.submitted.single.$3;
    expect(result.status, 'CANCELLED');
    expect(result.content, 'uno ');
    expect(
      host.speeds,
      isEmpty,
      reason: 'a partial run says nothing about speed',
    );
  });

  test('an engine failure is reported and submitted as FAILED', () async {
    engine
      ..deltas = ['parziale', 'mai']
      ..error = const LocalEngineException(LocalErrorCodes.outOfMemory)
      ..errorAfter = 1;
    final events = await run().toList();
    expect(
      events.whereType<AiStreamError>().single.code,
      'AI_LOCAL_OUT_OF_MEMORY',
    );
    expect((events.last as AiStreamDone).status, AiStatus.failed);
    final result = repo.submitted.single.$3;
    expect(
      (result.status, result.errorCode, result.content),
      ('FAILED', 'AI_LOCAL_OUT_OF_MEMORY', 'parziale'),
    );
  });

  test('a missing model or a refused prepare fails before any event', () async {
    await expectLater(
      run(r: runner(h: FakeModelHost(engine, missing: true))).toList(),
      throwsA(
        isA<DomainError>().having(
          (e) => e.code,
          'code',
          'AI_LOCAL_MODEL_MISSING',
        ),
      ),
    );
    repo.prepareError = const DomainError(
      code: 'AI_DATA_CHANGED',
      message: 'changed',
    );
    await expectLater(
      run().toList(),
      throwsA(
        isA<DomainError>().having((e) => e.code, 'code', 'AI_DATA_CHANGED'),
      ),
    );
    expect(repo.submitted, isEmpty);
  });

  test(
    "a result the server can't take now goes to the outbox and is sent later",
    () async {
      repo.submitError = const NetworkError();
      final events = await run().toList();
      expect(
        (events.last as AiStreamDone).status,
        AiStatus.completed,
        reason: 'the user still sees the report',
      );
      final pending = await outbox.pending();
      expect(pending.single.userId, 'u1');
      expect(pending.single.result.content, 'Ciao mondo');

      repo.submitError = null;
      await outbox.flush(repo, 'someone-else');
      expect(
        repo.submitted,
        isEmpty,
        reason: "only the owner's session sends it",
      );
      await outbox.flush(repo, 'u1');
      expect(repo.submitted.single.$3.content, 'Ciao mondo');
      expect(await outbox.pending(), isEmpty);
    },
  );

  test('the outbox drops refused and expired items', () async {
    var now = DateTime(2026, 10, 20);
    final box = MemoryLocalResultOutbox(now: () => now);
    PendingLocalResult item(String id) => PendingLocalResult(
      userId: 'u1',
      analysisId: 'a1',
      messageId: id,
      result: const AiLocalResult(content: 'x', status: 'COMPLETED'),
      createdAt: now,
    );
    await box.add(item('m1'));
    repo.submitError = const DomainError(
      code: 'AI_MESSAGE_FINISHED',
      message: 'saved',
    );
    await box.flush(repo, 'u1');
    expect(
      await box.pending(),
      isEmpty,
      reason: "a domain refusal won't change on retry",
    );

    await box.add(item('m2'));
    now = now.add(const Duration(days: 8));
    expect(await box.pending(), isEmpty);
  });

  test('the file outbox survives a restart', () async {
    final dir = await Directory.systemTemp.createTemp('outbox');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/ai_local/outbox.json');
    final first = FileLocalResultOutbox(() async => file);
    await first.add(
      PendingLocalResult(
        userId: 'u1',
        analysisId: 'a1',
        messageId: 'm1',
        result: const AiLocalResult(content: 'salvato', status: 'COMPLETED'),
        createdAt: DateTime.now(),
      ),
    );
    final second = FileLocalResultOutbox(() async => file);
    expect((await second.pending()).single.result.content, 'salvato');
    await second.flush(repo, 'u1');
    expect(repo.submitted.single.$3.content, 'salvato');
    expect(await file.exists(), isFalse);
  });

  test('follow-ups drop the oldest Q/A pairs to fit the context', () async {
    engine.tokensPerChar = 1;
    repo.followUpMessages = [
      const LocalChatMessage(role: 'user', content: 'dati'),
      const LocalChatMessage(role: 'assistant', content: 'report'),
      LocalChatMessage(role: 'user', content: 'q1' * 200),
      LocalChatMessage(role: 'assistant', content: 'a1' * 200),
      const LocalChatMessage(role: 'user', content: 'q2'),
      const LocalChatMessage(role: 'assistant', content: 'a2'),
      const LocalChatMessage(role: 'user', content: 'nuova'),
    ];
    final small = FakeModelHost(engine, contextTokens: 600);
    await runner(h: small).askFollowUp('a1', 'nuova').toList();
    expect(engine.lastRequest!.messages.map((m) => m.content), [
      'dati',
      'report',
      'q2',
      'a2',
      'nuova',
    ]);

    // Even data, report and the question alone don't fit: refused.
    repo.followUpMessages = [
      LocalChatMessage(role: 'user', content: 'd' * 900),
      const LocalChatMessage(role: 'assistant', content: 'report'),
      const LocalChatMessage(role: 'user', content: 'nuova'),
    ];
    final events = await runner(h: small).askFollowUp('a1', 'nuova').toList();
    expect(
      events.whereType<AiStreamError>().single.code,
      'AI_LOCAL_CONTEXT_TOO_LONG',
    );
    expect(repo.submitted.last.$3.status, 'FAILED');
  });

  test('the engine stops when the screen goes away', () async {
    engine
      ..deltas = List.filled(20, 'x')
      ..delay = const Duration(milliseconds: 20);
    final gotDelta = Completer<void>();
    final sub = run().listen((e) {
      if (e is AiStreamDelta && !gotDelta.isCompleted) gotDelta.complete();
    });
    await gotDelta.future;
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.cancelled, isTrue);
    expect(
      repo.submitted.single.$3.status,
      'CANCELLED',
      reason: 'the partial text is still saved',
    );
  });
}
