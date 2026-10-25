import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/session/current_user_provider.dart';
import '../../../core/api/providers.dart';
import '../../../core/errors/error_code_localizations.dart';
import '../../../core/platform/platform_info.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/presentation/view_models/account_providers.dart';
import '../domain/local/local_llm_engine.dart';
import '../domain/models/ai_analysis_request.dart';
import '../domain/models/ai_settings.dart';
import '../domain/models/ai_user_context.dart';
import '../domain/models/local_model_catalog.dart';
import '../domain/repositories/ai_repository.dart';
import 'local/ai_last_choice_store.dart';
import 'local/ai_notifier.dart';
import 'local/background_work.dart';
import 'local/device_capabilities_source.dart';
import 'local/engine_model_host.dart';
import 'local/engines/local_engines.dart';
import 'local/hugging_face_token_store.dart';
import 'local/local_ai_runner.dart';
import 'local/local_result_outbox.dart';
import 'local/model_benchmark.dart';
import 'local/model_downloader.dart';
import 'local/model_importer.dart';
import 'local/model_store.dart';
import 'local/network_status.dart';
import 'local/unavailable_model_host.dart';
import 'repositories/ai_repository_impl.dart';
import 'services/ai_api.dart';

final aiApiProvider = Provider<AiApi>((ref) {
  return AiApi(ref.watch(apiClientProvider).dio);
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(aiApiProvider));
});

/// Cached AI settings (provider, consent, setup checklist), shared by the
/// assistant hub, the Reports entry card and the analysis flow. Registered
/// in user_scoped_providers.dart; invalidate after saving settings,
/// consent, context, a wallet purpose or after an analysis.
final aiSettingsProvider = FutureProvider<AiSettings>((ref) {
  return ref.watch(aiRepositoryProvider).getSettings();
});

/// Cached personal context. Registered in user_scoped_providers.dart.
final aiUserContextProvider = FutureProvider<AiUserContext>((ref) {
  return ref.watch(aiRepositoryProvider).getUserContext();
});

/// Presets in the user's language. Registered in user_scoped_providers.dart
/// since the language follows the account's locale.
final aiPresetsProvider = FutureProvider<List<AiPreset>>((ref) {
  return ref.watch(aiRepositoryProvider).listPresets();
});

/// The phone's model manager (plan.md section 33): LiteRT-LM and llama.cpp
/// on Android arm64. Elsewhere (iOS) every on-device run reports
/// AI_LOCAL_UNSUPPORTED or AI_LOCAL_MODEL_MISSING.
final localModelHostProvider = Provider<LocalModelHost>((ref) {
  if (!isAndroidApp) return const UnavailableLocalModelHost();
  final host = EngineModelHost(
    store: ref.watch(modelStoreProvider),
    engines: createLocalEngines(),
    device: ref.watch(deviceCapabilitiesSourceProvider),
  );
  final observer = _MemoryPressureObserver(host.onMemoryPressure);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    host.release();
  });
  return host;
});

class _MemoryPressureObserver with WidgetsBindingObserver {
  _MemoryPressureObserver(this._onPressure);

  final Future<void> Function() _onPressure;

  @override
  void didHaveMemoryPressure() => _onPressure();
}

/// "Misura velocità" with the active model.
final modelBenchmarkProvider = Provider<ModelBenchmark>(
  (ref) => ModelBenchmark(ref.watch(localModelHostProvider)),
);

/// Results generated on the phone that the server hasn't received yet.
final localResultOutboxProvider = Provider<LocalResultOutbox>(
  (ref) => FileLocalResultOutbox(
    () async => File(
      '${(await getApplicationSupportDirectory()).path}/ai_local/outbox.json',
    ),
  ),
);

/// Sends results left in the outbox when someone signs in and whenever the
/// app comes back to the foreground; each run also flushes before it
/// starts. Watched by the root widget.
final localOutboxFlusherProvider = Provider<void>((ref) {
  void flush() {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    ref
        .read(localResultOutboxProvider)
        .flush(ref.read(aiRepositoryProvider), userId)
        .catchError((_) {})
        .whenComplete(() => ref.invalidate(localPendingResultsProvider));
  }

  ref.listen(
    currentUserProvider.select((u) => u?.id),
    (_, id) => id == null ? null : flush(),
    fireImmediately: true,
  );
  final observer = _ResumeObserver(flush);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
});

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final void Function() _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

/// Every result waiting on this phone, of any account (they are readable
/// by whoever uses the app here). Invalidated after a flush.
final localPendingResultsProvider =
    FutureProvider.autoDispose<List<PendingLocalResult>>(
      (ref) => ref.watch(localResultOutboxProvider).pending(),
    );

/// Not auto-disposed: a run must finish and submit its result even when
/// the screen that started it is gone.
final localAiRunnerProvider = Provider<LocalAiRunner>((ref) {
  final runner = LocalAiRunner(
    repo: ref.watch(aiRepositoryProvider),
    host: ref.watch(localModelHostProvider),
    outbox: ref.watch(localResultOutboxProvider),
    currentUserId: () => ref.read(currentUserProvider)?.id,
    currentUserName: () {
      final u = ref.read(currentUserProvider);
      return u == null ? null : '${u.firstName} ${u.lastName} (@${u.username})';
    },
    background: ref.watch(backgroundWorkProvider),
    notifier: ref.watch(aiNotifierProvider),
    texts: () {
      final l10n = ref.read(appL10nProvider);
      return LocalRunTexts(
        writingReport: l10n.bgWritingReport,
        writingAnswer: l10n.bgWritingAnswer,
        reportReadyTitle: l10n.notifyReportReadyTitle,
        answerReadyTitle: l10n.notifyAnswerReadyTitle,
        failedTitle: l10n.notifyAnalysisFailedTitle,
        fallbackBody: l10n.notifyAnalysisFallbackBody,
        describeError: (code) => localizeErrorCode(l10n, code),
      );
    },
    shouldNotify: () {
      // Off screen, or on screen but elsewhere; never with AI turned off.
      final profile = ref.exists(accountProfileProvider)
          ? ref.read(accountProfileProvider).value
          : null;
      return profile?.aiEnabled ?? true;
    },
    visibleAnalysisId: () => ref.read(appInForegroundProvider)()
        ? ref.read(aiVisibleAnalysisProvider)
        : null,
  );
  ref.onDispose(runner.dispose);
  return runner;
});

/// The analysis on screen now, set by the analysis screen: its runs don't
/// notify while the user reads them.
final aiVisibleAnalysisProvider = NotifierProvider<AiVisibleAnalysis, String?>(
  AiVisibleAnalysis.new,
);

class AiVisibleAnalysis extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String? id) => state = id;

  void hide(String? id) {
    if (state == id) state = null;
  }
}

/// Where the text of a turn comes from: the server streaming a cloud
/// provider, or the phone.
final aiTurnSourceProvider = Provider.family<AiTurnSource, AiMode>(
  (ref, mode) => mode == AiMode.onDevice
      ? ref.watch(localAiRunnerProvider)
      : ref.watch(aiRepositoryProvider),
);

/// Texts for code that runs without a BuildContext (notifications): the
/// account's language when its profile is already loaded, else the
/// phone's, else Italian. Computed on each read, without loading the
/// profile.
final appL10nProvider = Provider.autoDispose<AppLocalizations>((ref) {
  String? tag;
  if (ref.exists(accountProfileProvider)) {
    try {
      tag = ref.read(accountProfileProvider).value?.locale;
    } catch (_) {}
  }
  tag ??= ui.PlatformDispatcher.instance.locale.toLanguageTag();
  final code = tag.split(RegExp('[-_]')).first;
  return lookupAppLocalizations(
    Locale(
      AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
          ? code
          : 'it',
    ),
  );
});

/// The foreground service that keeps downloads and on-device analyses
/// going in the background (Android only).
final backgroundWorkProvider = Provider<BackgroundWork>((ref) {
  if (!isAndroidApp) return const NoopBackgroundWork();
  return ForegroundTaskBackgroundWork(() {
    final l10n = ref.read(appL10nProvider);
    return BackgroundTexts(
      title: l10n.bgWorkTitle,
      channel: l10n.bgWorkChannel,
      pause: l10n.aiLocalPause,
      stop: l10n.bgWorkStop,
    );
  });
});

/// "Analisi pronta", "Modello pronto" (Android only).
final aiNotifierProvider = Provider<AiNotifier>(
  (ref) => isAndroidApp ? LocalAiNotifier() : const NoopAiNotifier(),
);

/// Whether the app is on screen; overridden in tests.
final appInForegroundProvider = Provider<bool Function()>(
  (ref) => appInForeground,
);

final aiLastChoiceStoreProvider = Provider<AiLastChoiceStore>(
  (ref) => const SharedPrefsAiLastChoiceStore(),
);

/// The model the signed-in account last ran an analysis with on this
/// phone (an AiRunChoice key), or null.
final aiLastChoiceProvider = FutureProvider.autoDispose<String?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return null;
  return ref.watch(aiLastChoiceStoreProvider).read(userId);
});

/// The bundled catalog of downloadable models.
final localModelCatalogProvider = FutureProvider<LocalModelCatalog>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/ai/local_models.json');
  return LocalModelCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});

/// Installed models, in `<app support>/ai_models` (excluded from Android
/// backups by res/xml/backup_rules.xml and data_extraction_rules.xml).
final modelStoreProvider = Provider<ModelStore>(
  (ref) => ModelStore(
    () async =>
        Directory('${(await getApplicationSupportDirectory()).path}/ai_models'),
  ),
);

final deviceCapabilitiesSourceProvider = Provider<DeviceCapabilitiesSource>(
  (ref) => const PlatformDeviceCapabilitiesSource(),
);

final networkStatusProvider = Provider<NetworkStatus>(
  (ref) => ConnectivityNetworkStatus(),
);

final huggingFaceTokenStoreProvider = Provider<HuggingFaceTokenStore>(
  (ref) => HuggingFaceTokenStore(),
);

Future<int?> Function(Directory) _freeBytes(Ref ref) =>
    (_) async => (await ref.read(deviceCapabilitiesSourceProvider).read())
        ?.freeStorageBytes;

/// Its own Dio, not the API client's: model hosts must never see the app's
/// session token or request ids.
final modelDownloaderProvider = Provider<ModelDownloader>(
  (ref) => ModelDownloader(
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ),
    network: ref.watch(networkStatusProvider),
    freeBytes: _freeBytes(ref),
    huggingFaceToken: ref.watch(huggingFaceTokenStoreProvider).read,
  ),
);

final modelImporterProvider = Provider<ModelImporter>(
  (ref) => ModelImporter(
    store: ref.watch(modelStoreProvider),
    freeBytes: _freeBytes(ref),
  ),
);
