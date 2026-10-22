import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:financialmanager/features/ai/data/local/local_ai_runner.dart';
import 'package:financialmanager/features/ai/data/local/local_result_outbox.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_analysis_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_conversation_controller.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_run_plan.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

import 'fakes/fake_local_engine.dart';

/// An on-device analysis whose report the phone is still writing.
AiAnalysisDetail _detail({required bool streaming}) => AiAnalysisDetail(
  summary: AiAnalysisSummary(
    id: 'a1',
    title: 'Check-up',
    preset: 'MONTHLY_CHECKUP',
    periodTo: DateTime(2026, 10, 22),
    status: streaming ? AiStatus.streaming : AiStatus.completed,
    provider: AiProviderKind.onDevice,
    model: 'Gemma 4 E2B · int4 · LiteRT-LM',
    inputTokens: 0,
    outputTokens: 0,
    createdAt: DateTime(2026, 10, 22),
  ),
  systemPrompt: 'sys',
  messages: [
    const AiMessage(
      id: 'm1',
      kind: AiMessageKind.context,
      content: 'dati',
      status: AiStatus.completed,
    ),
    AiMessage(
      id: 'm2',
      kind: AiMessageKind.report,
      content: streaming ? '' : 'Report finito.',
      status: streaming ? AiStatus.streaming : AiStatus.completed,
    ),
  ],
  followUpsLeft: 20,
  canAskFollowUps: !streaming,
);

class _Repo implements AiRepository {
  bool streaming = true;
  int loads = 0;

  @override
  Future<AiAnalysisDetail> getAnalysis(String id) async {
    loads++;
    return _detail(streaming: streaming);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late _Repo repo;
  late LocalAiRunner runner;
  late FakeLocalEngine engine;

  ProviderContainer make() {
    engine = FakeLocalEngine();
    runner = LocalAiRunner(
      repo: repo,
      host: FakeModelHost(engine),
      outbox: MemoryLocalResultOutbox(),
      currentUserId: () => 'u1',
    );
    return ProviderContainer(
      overrides: [
        aiRepositoryProvider.overrideWithValue(repo),
        localAiRunnerProvider.overrideWithValue(runner),
        localAiSupportedProvider.overrideWithValue(false),
      ],
    );
  }

  setUp(() => repo = _Repo());

  test('a screen opened meanwhile follows the text, then reloads', () async {
    final c = make();
    addTearDown(c.dispose);
    runner.live.value = const LocalLiveTurn(
      analysisId: 'a1',
      messageId: 'm2',
      isReport: true,
      text: 'Hai speso',
    );
    c.listen(aiConversationControllerProvider('a1'), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    var s = c.read(aiConversationControllerProvider('a1'));
    expect(s.isStreaming, isTrue);
    expect(s.messages.last.content, 'Hai speso');

    runner.live.value = const LocalLiveTurn(
      analysisId: 'a1',
      messageId: 'm2',
      isReport: true,
      text: 'Hai speso poco.',
    );
    expect(
      c.read(aiConversationControllerProvider('a1')).messages.last.content,
      'Hai speso poco.',
    );

    // The phone has submitted it: the stored report replaces the live one.
    repo.streaming = false;
    runner.live.value = null;
    await Future<void>.delayed(Duration.zero);
    s = c.read(aiConversationControllerProvider('a1'));
    expect(s.isStreaming, isFalse);
    expect(s.messages.last.content, 'Report finito.');
    expect(repo.loads, 2);
  });

  testWidgets('leaving while the phone writes asks what to do', (tester) async {
    final c = make();
    addTearDown(c.dispose);
    runner.live.value = const LocalLiveTurn(
      analysisId: 'a1',
      messageId: 'm2',
      isReport: true,
      text: 'Hai speso',
    );
    final router = GoRouter(
      initialLocation: '/history',
      routes: [
        GoRoute(
          path: '/history',
          builder: (_, _) => const Scaffold(body: Text('Cronologia')),
        ),
        GoRoute(
          path: '/a1',
          builder: (_, _) => const AiAnalysisScreen(analysisId: 'a1'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    // The streaming bar animates forever: pump a while instead of settling.
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    router.push('/a1');
    await settle();
    expect(find.text('Hai speso'), findsOneWidget);

    // Stay: still here.
    await tester.binding.handlePopRoute();
    await settle();
    expect(find.text('Continua in background'), findsOneWidget);
    await tester.tap(find.text('Resta'));
    await settle();
    expect(find.text('Hai speso'), findsOneWidget);

    // Continue in background: back to the history, the turn goes on.
    await tester.binding.handlePopRoute();
    await settle();
    await tester.tap(find.text('Continua in background'));
    await settle();
    expect(find.text('Cronologia'), findsOneWidget);
    expect(engine.cancelled, isFalse);
  });
}
