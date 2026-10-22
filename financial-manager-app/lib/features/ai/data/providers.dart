import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/session/current_user_provider.dart';
import '../../../core/api/providers.dart';
import '../domain/local/local_llm_engine.dart';
import '../domain/models/local_model.dart';
import '../domain/models/ai_analysis_request.dart';
import '../domain/models/ai_settings.dart';
import '../domain/models/ai_user_context.dart';
import '../domain/models/local_model_catalog.dart';
import '../domain/repositories/ai_repository.dart';
import 'local/ai_last_choice_store.dart';
import 'local/device_capabilities_source.dart';
import 'local/engine_model_host.dart';
import 'local/engines/edge_ai_engine.dart';
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
/// on Android arm64. Elsewhere every on-device run reports
/// AI_LOCAL_UNSUPPORTED or AI_LOCAL_MODEL_MISSING.
final localModelHostProvider = Provider<LocalModelHost>((ref) {
  if (!Platform.isAndroid) return const UnavailableLocalModelHost();
  final host = EngineModelHost(
    store: ref.watch(modelStoreProvider),
    engines: {
      for (final kind in LocalEngineKind.values) kind: EdgeAiEngine(kind),
    },
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
final localAiRunnerProvider = Provider<LocalAiRunner>(
  (ref) => LocalAiRunner(
    repo: ref.watch(aiRepositoryProvider),
    host: ref.watch(localModelHostProvider),
    outbox: ref.watch(localResultOutboxProvider),
    currentUserId: () => ref.read(currentUserProvider)?.id,
    currentUserName: () {
      final u = ref.read(currentUserProvider);
      return u == null ? null : '${u.firstName} ${u.lastName} (@${u.username})';
    },
  ),
);

/// Where the text of a turn comes from: the server streaming a cloud
/// provider, or the phone.
final aiTurnSourceProvider = Provider.family<AiTurnSource, AiMode>(
  (ref, mode) => mode == AiMode.onDevice
      ? ref.watch(localAiRunnerProvider)
      : ref.watch(aiRepositoryProvider),
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
