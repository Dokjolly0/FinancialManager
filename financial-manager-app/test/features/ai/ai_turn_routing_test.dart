import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/ai_stream_event.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_conversation_controller.dart';

/// Records which source a turn went to.
class _Source implements AiTurnSource {
  _Source(this.name, this.log);

  final String name;
  final List<String> log;

  Stream<AiStreamEvent> _done() => Stream.fromIterable(const [
    AiStreamDelta('x'),
    AiStreamDone(AiStatus.completed),
  ]);

  @override
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) {
    log.add('$name:run');
    return _done();
  }

  @override
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  }) {
    log.add('$name:ask');
    return _done();
  }
}

class _Repo implements AiRepository {
  _Repo(this.provider);

  final AiProviderKind provider;

  @override
  Future<AiAnalysisDetail> getAnalysis(String id) async => AiAnalysisDetail(
    summary: AiAnalysisSummary(
      id: id,
      title: 't',
      preset: 'SAVINGS',
      periodTo: DateTime(2026, 10, 20),
      status: AiStatus.completed,
      provider: provider,
      model: 'm',
      inputTokens: 0,
      outputTokens: 0,
      createdAt: DateTime(2026, 10, 20),
    ),
    systemPrompt: 's',
    messages: const [
      AiMessage(
        id: 'r',
        kind: AiMessageKind.report,
        content: 'report',
        status: AiStatus.completed,
      ),
    ],
    followUpsLeft: 20,
    canAskFollowUps: true,
  );

  @override
  Future<AiSettings> getSettings() async => const AiSettings(
    available: true,
    consent: AiConsent(currentVersion: 1, required: false),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ProviderContainer _container(List<String> log, AiProviderKind storedProvider) =>
    ProviderContainer(
      overrides: [
        aiRepositoryProvider.overrideWithValue(_Repo(storedProvider)),
        aiTurnSourceProvider(
          AiMode.cloud,
        ).overrideWithValue(_Source('cloud', log)),
        aiTurnSourceProvider(
          AiMode.onDevice,
        ).overrideWithValue(_Source('local', log)),
      ],
    );

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('a run goes to the source of the preview target', () async {
    final log = <String>[];
    final c = _container(log, AiProviderKind.openai);
    addTearDown(c.dispose);
    c.listen(aiConversationControllerProvider(aiNewRunKey), (_, _) {});
    c
        .read(aiConversationControllerProvider(aiNewRunKey).notifier)
        .startRun(
          const AiAnalysisRequest(preset: 'SAVINGS'),
          'f',
          target: AiMode.onDevice,
        );
    await _settle();
    expect(log, ['local:run']);
  });

  test('follow-ups continue where the report was written', () async {
    final log = <String>[];
    for (final (provider, expected) in [
      (AiProviderKind.onDevice, 'local:ask'),
      (AiProviderKind.anthropic, 'cloud:ask'),
    ]) {
      log.clear();
      final c = _container(log, provider);
      c.listen(aiConversationControllerProvider('a1'), (_, _) {});
      await _settle();
      c.read(aiConversationControllerProvider('a1').notifier).ask('Perché?');
      await _settle();
      expect(log, [expected]);
      c.dispose();
    }
  });
}
