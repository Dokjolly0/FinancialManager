import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:financialmanager/app/router.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_chat_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_run_plan.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

class _Repo implements AiRepository {
  _Repo({this.consentRequired = false});

  final bool consentRequired;
  final previews = <AiAnalysisRequest>[];
  final consents = <(int, String)>[];

  @override
  Future<AiSettings> getSettings() async => AiSettings(
    available: true,
    consent: AiConsent(currentVersion: 2, required: consentRequired),
    credentials: const [
      AiCredential(
        id: 'c1',
        provider: AiProviderKind.openai,
        model: 'gpt-test',
        hasKey: true,
      ),
    ],
  );

  @override
  Future<void> acceptConsent(int version, {String scope = 'cloud'}) async =>
      consents.add((version, scope));

  @override
  Future<AiPreview> preview(AiAnalysisRequest request) async {
    previews.add(request);
    return AiPreview.fromJson({
      'provider': 'openai',
      'model': 'gpt-test',
      'system_prompt': 's',
      'instructions': request.instructions,
      'data_block': '<financial_data></financial_data>',
      'data_fingerprint': 'f' * 64,
      'estimated_input_tokens': 100,
      'max_output_tokens': 1024,
      'period_to': '2026-10-25',
      'target': 'cloud',
      'disclosure': {'sections': <String>[], 'wallet_count': 1},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AiChatScreen()),
      GoRoute(path: AppRoutes.aiRun, builder: (_, _) => const Text('RUN')),
      GoRoute(path: AppRoutes.aiHistory, builder: (_, _) => const Text('H')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiRepositoryProvider.overrideWithValue(repo),
        localAiSupportedProvider.overrideWithValue(false),
        aiLastChoiceProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp.router(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

IconButton _sendButton(WidgetTester tester) => tester.widget<IconButton>(
  find.ancestor(of: find.byIcon(Icons.send), matching: find.byType(IconButton)),
);

void main() {
  testWidgets('an example fills the question; sending runs a chat', (
    tester,
  ) async {
    final repo = _Repo();
    await _pump(tester, repo);
    expect(find.text("Chiedi all'assistente"), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNull, reason: 'empty question');

    await tester.tap(
      find.text("Quando ho pagato l'assicurazione della macchina?"),
    );
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    final sent = repo.previews.single;
    expect(sent.preset, aiChatPreset);
    expect(
      sent.instructions,
      "Quando ho pagato l'assicurazione della macchina?",
    );
    expect(sent.toJson()['period'], {'preset': 'all_time'});
    expect((sent.toJson()['options'] as Map)['max_transactions'], 2000);
    expect(sent.target, 'cloud');
    expect(sent.credentialId, 'c1');
    expect(find.text('RUN'), findsOneWidget);
  });

  testWidgets('the consent comes first when required', (tester) async {
    final repo = _Repo(consentRequired: true);
    await _pump(tester, repo);
    await tester.enterText(
      find.byKey(const ValueKey('chat-question')),
      'Quanto spendo di benzina?',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(repo.previews, isEmpty);

    await tester.scrollUntilVisible(
      find.text('Ho capito, accetto'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Ho capito, accetto'));
    await tester.pumpAndSettle();
    expect(repo.consents, [(2, 'cloud')]);
    expect(repo.previews.single.instructions, 'Quanto spendo di benzina?');
  });
}
