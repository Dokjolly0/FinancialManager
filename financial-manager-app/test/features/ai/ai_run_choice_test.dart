import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:financialmanager/features/account/domain/models/user_profile.dart';
import 'package:financialmanager/features/account/presentation/view_models/account_providers.dart';
import 'package:financialmanager/features/ai/data/local/ai_last_choice_store.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_run_choice.dart';
import 'package:financialmanager/features/reports/presentation/widgets/ai_analysis_entry_card.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

AiCredential _cred(
  String id,
  AiProviderKind provider, {
  String? model = 'm',
  bool hasKey = true,
}) => AiCredential(id: id, provider: provider, model: model, hasKey: hasKey);

LocalModelRecord _local(String id) => LocalModelRecord(
  id: id,
  engine: LocalEngineKind.litertLm,
  modelType: 'gemma4',
  displayName: 'Gemma 4 E2B',
  quantization: 'int4',
  fileName: 'm.litertlm',
  sizeBytes: 1,
  sha256: 'a' * 64,
  verified: true,
  source: LocalModelSource.catalog,
  installedAt: DateTime.utc(2026, 10, 22),
  defaultContextTokens: 16384,
  maxContextTokens: 16384,
  backends: const [LocalBackend.gpu],
);

AiSettings _settings({
  AiMode mode = AiMode.cloud,
  bool available = true,
  bool onDevice = true,
  String? activeId = 'gemini',
}) {
  final creds = [
    _cred('openai', AiProviderKind.openai),
    _cred('gemini', AiProviderKind.gemini),
    _cred('nomodel', AiProviderKind.anthropic, model: null),
    _cred('nokey', AiProviderKind.anthropic, hasKey: false),
    _cred('ollama', AiProviderKind.openaiCompatible, hasKey: false),
  ];
  return AiSettings(
    available: available,
    onDeviceAvailable: onDevice,
    mode: mode,
    credentials: creds,
    active: creds.where((c) => c.id == activeId).firstOrNull,
    consent: const AiConsent(currentVersion: 1, required: false),
  );
}

void main() {
  group('choices', () {
    test('every usable cloud account, then the installed models', () {
      final choices = aiRunChoices(
        _settings(),
        localSupported: true,
        installed: [_local('g1'), _local('g2')],
      );
      expect(choices.map((c) => c.key), [
        'cloud:openai',
        'cloud:gemini',
        'cloud:ollama',
        'local:g1',
        'local:g2',
      ]);
    });

    test('a path that is off contributes nothing', () {
      expect(
        aiRunChoices(
          _settings(onDevice: false),
          localSupported: true,
          installed: [_local('g1')],
        ).any((c) => c.isOnDevice),
        isFalse,
      );
      expect(
        aiRunChoices(
          _settings(),
          localSupported: false,
          installed: [_local('g1')],
        ).any((c) => c.isOnDevice),
        isFalse,
        reason: 'no engines on this phone',
      );
      expect(
        aiRunChoices(
          _settings(available: false),
          localSupported: true,
          installed: [_local('g1')],
        ).map((c) => c.key),
        ['local:g1'],
      );
    });

    test('the default follows the saved mode', () {
      List<AiRunChoice> choices(AiSettings s) => aiRunChoices(
        s,
        localSupported: true,
        installed: [_local('g1'), _local('g2')],
      );
      final cloud = _settings();
      expect(
        defaultAiRunChoice(
          choices(cloud),
          cloud,
          activeLocalModelId: 'g2',
        )!.key,
        'cloud:gemini',
      );
      final local = _settings(mode: AiMode.onDevice);
      expect(
        defaultAiRunChoice(
          choices(local),
          local,
          activeLocalModelId: 'g2',
        )!.key,
        'local:g2',
      );
      expect(
        defaultAiRunChoice(choices(local), local)!.key,
        'local:g1',
        reason: 'no active phone model: the first',
      );
      final noActive = _settings(activeId: null);
      expect(
        defaultAiRunChoice(choices(noActive), noActive)!.key,
        'cloud:openai',
      );
      expect(defaultAiRunChoice(const [], cloud), isNull);
    });

    test('the last model used comes first while it is still there', () {
      final s = _settings(mode: AiMode.onDevice);
      final choices = aiRunChoices(
        s,
        localSupported: true,
        installed: [_local('g1')],
      );
      expect(
        defaultAiRunChoice(
          choices,
          s,
          activeLocalModelId: 'g1',
          lastKey: 'cloud:openai',
        )!.key,
        'cloud:openai',
      );
      expect(
        defaultAiRunChoice(
          choices,
          s,
          activeLocalModelId: 'g1',
          lastKey: 'cloud:removed',
        )!.key,
        'local:g1',
        reason: 'gone: back to the saved mode',
      );
    });

    test('the last model is kept per account', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPrefsAiLastChoiceStore();
      await store.write('u1', 'cloud:gemini');
      await store.write('u2', 'local:g1');
      expect(await store.read('u1'), 'cloud:gemini');
      expect(await store.read('u2'), 'local:g1');
      expect(await store.read('u3'), isNull);
    });

    test('a cloud choice sends its account with the request', () {
      const r = AiAnalysisRequest(
        preset: 'MONTHLY_CHECKUP',
        credentialId: 'c1',
      );
      expect(r.toJson()['credential_id'], 'c1');
      expect(r.copyWith(instructions: 'x').credentialId, 'c1');
      expect(
        const AiAnalysisRequest(
          preset: 'X',
        ).toJson().containsKey('credential_id'),
        isFalse,
      );
    });
  });

  group('AI switch', () {
    UserProfile profile({required bool ai}) => UserProfile.fromJson({
      'id': 'u1',
      'first_name': 'A',
      'last_name': 'B',
      'username': 'ab',
      'email': 'a@b.c',
      'email_verified': true,
      'avatar_mode': 'generated',
      'avatar_background_color': '#336699',
      'avatar_text_color': '#FFFFFF',
      'locale': 'it-IT',
      'timezone': 'Europe/Rome',
      'theme': 'system',
      'balance_hidden_default': false,
      'first_day_of_week': 'monday',
      'ai_enabled': ai,
      'version': 1,
      'created_at': '2026-10-22T08:00:00Z',
    });

    Future<void> pumpCard(
      WidgetTester tester, {
      required bool ai,
      required AiSettings settings,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountProfileProvider.overrideWith((ref) async => profile(ai: ai)),
            aiSettingsProvider.overrideWith((ref) async => settings),
          ],
          child: const MaterialApp(
            locale: Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AiAnalysisEntryCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('off hides the Reports card', (tester) async {
      await pumpCard(tester, ai: false, settings: _settings());
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('on shows it, also when only the phone runs analyses', (
      tester,
    ) async {
      await pumpCard(
        tester,
        ai: true,
        settings: _settings(available: false, mode: AiMode.onDevice),
      );
      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Analizza'), findsOneWidget);
    });
  });
}
