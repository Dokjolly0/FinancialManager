import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_provider_settings_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_provider_form.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

const _storedAnthropic = AiCredential(
  id: 'c1',
  provider: AiProviderKind.anthropic,
  model: 'claude-x',
  hasKey: true,
  keyHint: 'sk-…1234',
);

void main() {
  group('buildSaveAiSettingsParams', () {
    test('an untouched key field keeps the stored key', () {
      final params = buildSaveAiSettingsParams(
        const AiProviderFormValues(
          provider: AiProviderKind.anthropic,
          model: ' claude-x ',
        ),
        expectedVersion: 2,
      );
      expect(params.apiKey, isNull);
      expect(params.toJson().containsKey('api_key'), isFalse);
      expect(params.model, 'claude-x');
      expect(params.expectedVersion, 2);
    });

    test('a typed key replaces it', () {
      final params = buildSaveAiSettingsParams(
        const AiProviderFormValues(
          provider: AiProviderKind.anthropic,
          model: 'm',
          apiKeyInput: ' sk-new ',
        ),
        expectedVersion: 1,
      );
      expect(params.apiKey, 'sk-new');
    });

    test('remove sends an empty key', () {
      final params = buildSaveAiSettingsParams(
        const AiProviderFormValues(
          provider: AiProviderKind.openaiCompatible,
          baseUrl: 'https://llm.example.com/v1',
          model: 'llama',
          removeStoredKey: true,
        ),
        expectedVersion: 1,
      );
      expect(params.apiKey, '');
      expect(params.baseUrl, 'https://llm.example.com/v1');
    });

    test('native providers never send a base URL', () {
      final params = buildSaveAiSettingsParams(
        const AiProviderFormValues(
          provider: AiProviderKind.openai,
          baseUrl: 'https://x',
          model: 'm',
        ),
        expectedVersion: 0,
      );
      expect(params.baseUrl, '');
    });
  });

  group('validateAiProviderForm', () {
    test('a native provider needs a key, typed or stored', () {
      const values = AiProviderFormValues(
        provider: AiProviderKind.anthropic,
        model: 'claude-x',
      );
      expect(validateAiProviderForm(values), {'api_key': 'REQUIRED_FIELD'});
      expect(validateAiProviderForm(values, stored: _storedAnthropic), isEmpty);
    });

    test('a compatible provider needs a base URL but no key', () {
      const values = AiProviderFormValues(
        provider: AiProviderKind.openaiCompatible,
        model: 'llama',
      );
      expect(validateAiProviderForm(values), {'base_url': 'REQUIRED_FIELD'});
    });

    test('model, token range and prices', () {
      const values = AiProviderFormValues(
        provider: AiProviderKind.gemini,
        apiKeyInput: 'k',
        maxOutputTokens: 10,
        inputPrice: -1,
      );
      expect(validateAiProviderForm(values), {
        'model': 'REQUIRED_FIELD',
        'max_output_tokens': 'VALUE_OUT_OF_RANGE',
        'input_price_per_mtok': 'NEGATIVE_NOT_ALLOWED',
      });
    });
  });

  test('parseAiPrice accepts a comma or a dot', () {
    expect(parseAiPrice('3,5'), 3.5);
    expect(parseAiPrice(' 0.25 '), 0.25);
    expect(parseAiPrice(''), isNull);
    expect(parseAiPrice('abc'), isNull);
  });

  testWidgets('the base URL field only appears for compatible providers', (
    tester,
  ) async {
    const settings = AiSettings(
      available: true,
      active: _storedAnthropic,
      credentials: [_storedAnthropic],
      consent: AiConsent(currentVersion: 1, required: false),
      version: 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiSettingsProvider.overrideWith((ref) async => settings)],
        child: const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiProviderSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Indirizzo del servizio (base URL)'), findsNothing);
    expect(
      find.text('Chiave salvata sk-…1234'),
      findsOneWidget,
      reason: 'the stored key shows only its hint',
    );

    await tester.tap(find.byType(DropdownButtonFormField<AiProviderKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Compatibile OpenAI').last);
    await tester.pumpAndSettle();

    expect(find.text('Indirizzo del servizio (base URL)'), findsOneWidget);
    expect(find.text('Mistral'), findsOneWidget, reason: 'base URL presets');
    expect(find.text('Chiave API (se richiesta)'), findsOneWidget);
  });
}
