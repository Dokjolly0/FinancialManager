import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/hugging_face_token_store.dart';
import 'package:financialmanager/features/ai/data/local/model_downloader.dart';
import 'package:financialmanager/features/ai/data/local/model_store.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/device_capabilities.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_catalog.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_local_models_screen.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_prompt_preview_screen.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_provider_settings_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_draft_controller.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_models_controller.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_run_plan.dart';
import 'package:financialmanager/features/ai/presentation/widgets/ai_consent_sheet.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

class _Repo implements AiRepository {
  AiSettings settings = const AiSettings(
    available: true,
    onDeviceAvailable: true,
    consent: AiConsent(currentVersion: 1, required: false),
    localConsent: AiConsent(currentVersion: 1, required: true),
    version: 3,
  );
  int estimatedTokens = 1000;
  final modes = <(AiMode, String?, int)>[];
  final consents = <(int, String)>[];

  @override
  Future<AiSettings> getSettings() async => settings;

  @override
  Future<AiSettings> setMode(
    AiMode mode, {
    String? localModel,
    required int expectedVersion,
  }) async {
    modes.add((mode, localModel, expectedVersion));
    settings = AiSettings(
      available: settings.available,
      onDeviceAvailable: settings.onDeviceAvailable,
      mode: mode,
      localModel: localModel,
      consent: settings.consent,
      localConsent: settings.localConsent,
      version: expectedVersion + 1,
    );
    return settings;
  }

  @override
  Future<void> acceptConsent(int version, {String scope = 'cloud'}) async =>
      consents.add((version, scope));

  @override
  Future<AiPreview> preview(AiAnalysisRequest request) async =>
      AiPreview.fromJson({
        'provider': 'on_device',
        'model': 'Gemma 4 E2B · int4',
        'system_prompt': 'REGOLE',
        'instructions': 'Istruzioni',
        'data_block': 'DATI',
        'data_fingerprint': '$estimatedTokens'.padLeft(64, 'f'),
        'estimated_input_tokens': estimatedTokens,
        'max_output_tokens': 1024,
        'period_to': '2026-10-20',
        'target': 'on_device',
        'disclosure': {'wallet_count': 1, 'profile': request.profile},
      });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Tokens extends HuggingFaceTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;
}

/// No model installed, without touching the disk (file IO never completes
/// in a widget test's fake time).
class _EmptyStore extends ModelStore {
  _EmptyStore() : super(() async => Directory('unused'));

  @override
  Future<String?> get activeModelId async => null;
}

/// The models screen's controller with a fixed state.
class _Controller extends LocalModelsController {
  _Controller(this.initial);

  final LocalModelsState initial;
  final downloads = <String>[];
  final paused = <String>[];

  @override
  LocalModelsState build() => initial;

  @override
  void download(String specId) => downloads.add(specId);

  @override
  void pause(String id) => paused.add(id);

  @override
  Future<void> refreshCapabilities() async {}
}

LocalModelSpec _spec(
  String id, {
  bool gated = false,
  bool recommended = false,
}) => LocalModelSpec.fromJson({
  'id': id,
  'family': 'gemma4',
  'display_name': 'Model $id',
  'engine': 'litert_lm',
  'format': 'litertlm',
  'model_type': 'gemma4',
  'quantization': 'int4',
  'url': 'https://huggingface.co/org/$id/resolve/${'0' * 40}/$id.litertlm',
  'revision': '0' * 40,
  'sha256': 'a' * 64,
  'size_bytes': 2588147712,
  'ram_min_mb': 6144,
  'ram_recommended_mb': 8192,
  'context_default': 16384,
  'context_max': 16384,
  'backends': ['gpu', 'cpu'],
  'token_factor': 1.59,
  'speed': {
    'gpu': {'prefill_tps': 600, 'decode_tps': 30},
  },
  'notes': {'it': 'Nota $id', 'en': 'Note $id'},
  'license': {
    'id': gated ? 'gemma' : 'apache-2.0',
    'url': 'https://example.com/license',
    'gated': gated,
  },
  'recommended': recommended,
});

LocalRunPlan _plan() => LocalRunPlan(
  record: LocalModelRecord(
    id: 'gemma',
    engine: LocalEngineKind.litertLm,
    modelType: 'gemma4',
    displayName: 'Gemma 4 E2B',
    quantization: 'int4',
    fileName: 'm.litertlm',
    sizeBytes: 10,
    sha256: 'a' * 64,
    verified: true,
    source: LocalModelSource.catalog,
    installedAt: DateTime.utc(2026, 10, 21),
    defaultContextTokens: 4096,
    maxContextTokens: 16384,
    backends: const [LocalBackend.gpu],
    tokenFactor: 1.6,
  ),
  params: const LocalRuntimeParams(
    contextTokens: 4096,
    maxOutputTokens: 1024,
    backend: LocalBackend.gpu,
  ),
  speed: const LocalSpeed(prefillTps: 600, decodeTps: 30),
  speedSource: LocalSpeedSource.catalog,
);

Widget _app(ProviderContainer c, Widget home) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  group('preview on the phone', () {
    Future<ProviderContainer> pumpPreview(
      WidgetTester tester,
      int estimatedTokens,
    ) async {
      repo.estimatedTokens = estimatedTokens;
      final c = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(repo),
          localAiSupportedProvider.overrideWithValue(false),
          localRunPlanProvider.overrideWith((ref) async => _plan()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(localRunPlanProvider, (_, _) {});
      await c
          .read(aiDraftControllerProvider.notifier)
          .preview(
            const AiAnalysisRequest(
              preset: 'MONTHLY_CHECKUP',
              includeTransactions: true,
              target: 'on_device',
            ),
          );
      await tester.pumpWidget(_app(c, const AiPromptPreviewScreen()));
      await tester.pumpAndSettle();
      return c;
    }

    FilledButton runButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Avvia sul telefono'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );

    LinearProgressIndicator bar(WidgetTester tester) =>
        tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('local-context-bar')),
        );

    testWidgets('fits: green bar, time estimate, no cost, runnable', (
      tester,
    ) async {
      await pumpPreview(tester, 1000);
      expect(
        find.text('Elaborato sul telefono con Gemma 4 E2B · int4'),
        findsOneWidget,
      );
      expect(find.text('Nessun costo'), findsOneWidget);
      // 1000 × 1.6 + 1024 + 256 = 2880 of 4096.
      expect(find.text('Contesto: 2.880 di 4.096 token'), findsOneWidget);
      expect(find.textContaining('stima'), findsWidgets);
      expect(bar(tester).color, Colors.green.shade600);
      expect(find.textContaining('Tempo stimato:'), findsOneWidget);
      expect(find.text('Meno movimenti'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Avvia sul telefono'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(runButton(tester).onPressed, isNotNull);
    });

    testWidgets('nearly full: amber bar with quick fixes', (tester) async {
      // 1700 × 1.6 + 1280 = 4000 of 4096.
      await pumpPreview(tester, 1700);
      expect(bar(tester).color, Colors.amber.shade700);
      expect(find.textContaining('Quasi pieno'), findsOneWidget);
      expect(find.text('Profilo compatto'), findsOneWidget);
    });

    testWidgets('too long: red bar, fixes, and the run is blocked', (
      tester,
    ) async {
      final c = await pumpPreview(tester, 3000);
      final scheme = Theme.of(
        tester.element(find.byType(AiPromptPreviewScreen)),
      ).colorScheme;
      expect(bar(tester).color, scheme.error);
      expect(find.textContaining('Non entra nel contesto'), findsOneWidget);
      for (final fix in [
        'Profilo compatto',
        'Meno movimenti',
        'Risposta più corta',
        'Contesto più grande',
      ]) {
        expect(find.text(fix), findsOneWidget, reason: fix);
      }

      // A fix previews again with the change.
      await tester.tap(find.text('Meno movimenti'));
      await tester.pumpAndSettle();
      expect(
        c.read(aiDraftControllerProvider).request!.maxTransactions,
        aiDefaultMaxTransactions ~/ 2,
      );

      await tester.scrollUntilVisible(
        find.text('Avvia sul telefono'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(runButton(tester).onPressed, isNull);
    });
  });

  group('models screen', () {
    late _Tokens tokens;

    Future<_Controller> pumpModels(
      WidgetTester tester,
      LocalModelsState state,
    ) async {
      tokens = _Tokens();
      final controller = _Controller(state);
      final c = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(repo),
          localModelsControllerProvider.overrideWith(() => controller),
          huggingFaceTokenStoreProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const AiLocalModelsScreen()));
      await tester.pumpAndSettle();
      return controller;
    }

    final catalog = LocalModelCatalog(
      schemaVersion: 1,
      catalogVersion: 1,
      models: [
        _spec('alpha', recommended: true),
        _spec('beta'),
        _spec('gamma', gated: true),
      ],
    );

    testWidgets('shows progress, pause, failures and the RAM fit', (
      tester,
    ) async {
      final controller = await pumpModels(
        tester,
        LocalModelsState(
          catalog: catalog,
          isLoading: false,
          capabilities: const DeviceCapabilities(
            totalMemBytes: 11623399424,
            freeStorageBytes: 50 * 1024 * 1024 * 1024,
          ),
          tasks: const {
            'alpha': LocalModelTask(
              id: 'alpha',
              status: LocalModelTaskStatus.downloading,
              receivedBytes: 1024 * 1024 * 1024,
              totalBytes: 2588147712,
            ),
            'beta': LocalModelTask(
              id: 'beta',
              status: LocalModelTaskStatus.failed,
              errorCode: ModelDownloadErrors.noSpace,
            ),
          },
        ),
      );
      expect(find.text('Consigliato'), findsOneWidget);
      expect(find.text('RAM sufficiente'), findsWidgets);
      expect(find.text('1,0 GB di 2,4 GB'), findsOneWidget);
      expect(
        find.text('Spazio insufficiente sul telefono per questo modello.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
      await tester.tap(find.text('Pausa'));
      expect(controller.paused, ['alpha']);
    });

    testWidgets('a download asks to accept the license first', (tester) async {
      final controller = await pumpModels(
        tester,
        LocalModelsState(catalog: catalog, isLoading: false),
      );
      await tester.tap(find.text('Scarica').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('licenza apache-2.0'), findsOneWidget);
      expect(find.text('Token di lettura'), findsNothing);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(controller.downloads, isEmpty);

      await tester.tap(find.text('Scarica').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accetta e scarica'));
      await tester.pumpAndSettle();
      expect(controller.downloads, ['alpha']);
    });

    testWidgets('a gated model asks for a Hugging Face token', (tester) async {
      final controller = await pumpModels(
        tester,
        LocalModelsState(catalog: catalog, isLoading: false),
      );
      await tester.scrollUntilVisible(
        find.text('Model gamma · int4'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Scarica').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scarica').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('modello è riservato'), findsOneWidget);
      expect(find.text('https://huggingface.co/org/gamma'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hf_secret');
      await tester.tap(find.text('Accetta e scarica'));
      await tester.pumpAndSettle();
      expect(tokens.token, 'hf_secret');
      expect(controller.downloads, ['gamma']);
    });
  });

  testWidgets('the on-device disclosure has its own text and scope', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      _app(
        c,
        const Scaffold(
          body: AiConsentSheet(consentVersion: 2, mode: AiMode.onDevice),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dove vengono elaborati i dati'), findsOneWidget);
    expect(find.text('Il modello può sbagliare'), findsOneWidget);
    expect(find.text('La tua chiave API'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ho capito, accetto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ho capito, accetto'));
    await tester.pumpAndSettle();
    expect(repo.consents, [(2, 'on_device')]);
  });

  testWidgets('the mode switch moves analyses to the phone', (tester) async {
    final c = ProviderContainer(
      overrides: [
        aiRepositoryProvider.overrideWithValue(repo),
        localAiSupportedProvider.overrideWithValue(true),
        modelStoreProvider.overrideWithValue(_EmptyStore()),
        localRunPlanProvider.overrideWith((ref) async => _plan()),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, const AiProviderSettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('Chiave API'), findsOneWidget, reason: 'cloud form');

    await tester.tap(find.text('Sul dispositivo'));
    await tester.pumpAndSettle();
    expect(repo.modes, [(AiMode.onDevice, null, 3)]);
    expect(find.text('Modelli sul dispositivo'), findsOneWidget);
    expect(find.text('Gemma 4 E2B · int4'), findsOneWidget);
    expect(
      find.text('GPU · contesto 4k · risposta fino a 1024 token'),
      findsOneWidget,
    );
    expect(find.text('Informativa sul dispositivo'), findsOneWidget);
  });
}
