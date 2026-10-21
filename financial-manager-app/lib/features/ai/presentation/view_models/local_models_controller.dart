import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/model_downloader.dart';
import '../../data/local/model_importer.dart';
import '../../data/providers.dart';
import '../../domain/models/device_capabilities.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';

enum LocalModelTaskStatus {
  queued,
  downloading,
  paused,
  waitingForWifi,
  verifying,
  failed,
}

/// A download in the queue: a catalog model (id = the spec's id) or a URL
/// import (id = a fresh "import-…" id).
class LocalModelTask {
  const LocalModelTask({
    required this.id,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes,
    this.errorCode,
    this.urlImport,
  });

  final String id;
  final LocalModelTaskStatus status;
  final int receivedBytes;
  final int? totalBytes;
  final String? errorCode;
  final LocalUrlImport? urlImport;

  double? get progress => totalBytes == null || totalBytes == 0
      ? null
      : receivedBytes / totalBytes!;

  bool get isActive =>
      status == LocalModelTaskStatus.downloading ||
      status == LocalModelTaskStatus.verifying;

  LocalModelTask copyWith({
    LocalModelTaskStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? errorCode,
  }) => LocalModelTask(
    id: id,
    status: status ?? this.status,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    errorCode: errorCode,
    urlImport: urlImport,
  );
}

class LocalUrlImport {
  const LocalUrlImport({
    required this.url,
    required this.target,
    required this.metadata,
    this.sha256,
  });

  final String url;
  final File target;
  final ModelImportMetadata metadata;
  final String? sha256;
}

class LocalModelsState {
  const LocalModelsState({
    this.catalog,
    this.installed = const [],
    this.activeModelId,
    this.tasks = const {},
    this.wifiOnly = true,
    this.capabilities,
    this.isLoading = true,
    this.importProgress,
    this.loadError,
  });

  final LocalModelCatalog? catalog;
  final List<LocalModelRecord> installed;

  /// The installed model on-device runs use.
  final String? activeModelId;

  /// In queue order.
  final Map<String, LocalModelTask> tasks;
  final bool wifiOnly;
  final DeviceCapabilities? capabilities;
  final bool isLoading;

  /// 0..1 while a picked file is copied in; null otherwise.
  final double? importProgress;
  final Object? loadError;

  LocalModelRecord? installedById(String id) {
    for (final r in installed) {
      if (r.id == id) return r;
    }
    return null;
  }

  RamFit ramFit(LocalModelSpec spec) =>
      ramFitForSpec(spec, capabilities?.totalMemBytes);

  LocalModelsState copyWith({
    LocalModelCatalog? catalog,
    List<LocalModelRecord>? installed,
    String? Function()? activeModelId,
    Map<String, LocalModelTask>? tasks,
    bool? wifiOnly,
    DeviceCapabilities? capabilities,
    bool? isLoading,
    double? Function()? importProgress,
    Object? Function()? loadError,
  }) => LocalModelsState(
    catalog: catalog ?? this.catalog,
    installed: installed ?? this.installed,
    activeModelId: activeModelId == null ? this.activeModelId : activeModelId(),
    tasks: tasks ?? this.tasks,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    capabilities: capabilities ?? this.capabilities,
    isLoading: isLoading ?? this.isLoading,
    importProgress: importProgress == null
        ? this.importProgress
        : importProgress(),
    loadError: loadError == null ? this.loadError : loadError(),
  );
}

/// Catalog, installed models and the download queue (plan.md section 33).
///
/// One download runs at a time, in queue order. A paused download keeps
/// its partial file; partial files found at start show up as paused.
/// With "Wi-Fi only", a download waits off Wi-Fi and resumes by itself
/// when Wi-Fi comes back.
class LocalModelsController extends Notifier<LocalModelsState> {
  String? _running;
  CancelToken? _runningToken;

  /// Ids whose partial file goes once their download has stopped.
  final _discardAfterStop = <String>{};

  /// Ids queued again once their download has stopped (a rule changed).
  final _resumeAfterStop = <String>{};
  StreamSubscription<bool>? _network;

  @override
  LocalModelsState build() {
    _network = ref.read(networkStatusProvider).unmeteredChanges.listen((
      unmetered,
    ) {
      if (unmetered) _requeue(LocalModelTaskStatus.waitingForWifi);
    });
    ref.onDispose(() {
      _network?.cancel();
      _runningToken?.cancel('disposed');
    });
    Future.microtask(_load);
    return const LocalModelsState();
  }

  Future<void> _load() async {
    final store = ref.read(modelStoreProvider);
    try {
      final catalog = await ref.read(localModelCatalogProvider.future);
      final installed = await store.list();
      final active = await store.activeModelId;
      final tasks = <String, LocalModelTask>{};
      for (final spec in catalog.models) {
        if (installed.any((r) => r.id == spec.id)) continue;
        final part = File(
          '${(await store.fileFor(spec.id, spec.fileName)).path}.part',
        );
        if (await part.exists()) {
          tasks[spec.id] = LocalModelTask(
            id: spec.id,
            status: LocalModelTaskStatus.paused,
            receivedBytes: await part.length(),
            totalBytes: spec.sizeBytes,
          );
        }
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        catalog: catalog,
        installed: installed,
        activeModelId: () =>
            installed.any((r) => r.id == active) ? active : null,
        tasks: {...tasks, ...state.tasks},
        wifiOnly: await store.wifiOnly,
        isLoading: false,
        loadError: () => null,
      );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, loadError: () => e);
      }
    }
    await refreshCapabilities();
  }

  Future<void> refreshCapabilities() async {
    if (!ref.mounted) return;
    final caps = await ref.read(deviceCapabilitiesSourceProvider).read();
    if (caps != null && ref.mounted) {
      state = state.copyWith(capabilities: caps);
    }
  }

  void download(String specId) {
    if (state.installedById(specId) != null) return;
    final task = state.tasks[specId];
    if (task != null &&
        task.status != LocalModelTaskStatus.paused &&
        task.status != LocalModelTaskStatus.failed) {
      return;
    }
    _setTask(
      (task ?? LocalModelTask(id: specId, status: LocalModelTaskStatus.queued))
          .copyWith(status: LocalModelTaskStatus.queued),
    );
    _pump();
  }

  /// Same as [download]: picks a paused or failed download up again.
  void resume(String id) {
    final task = state.tasks[id];
    if (task == null) return;
    if (task.urlImport != null) {
      _setTask(task.copyWith(status: LocalModelTaskStatus.queued));
      _pump();
    } else {
      download(id);
    }
  }

  void pause(String id) {
    final task = state.tasks[id];
    if (task == null) return;
    if (_running == id) {
      _runningToken?.cancel('paused');
    } else {
      _setTask(task.copyWith(status: LocalModelTaskStatus.paused));
    }
  }

  /// Stops the download and deletes its partial file.
  Future<void> cancel(String id) async {
    if (_running == id) {
      _discardAfterStop.add(id);
      _runningToken?.cancel('cancelled');
      return;
    }
    _removeTask(id);
    await ref.read(modelStoreProvider).remove(id);
  }

  /// Deletes an installed model (or a download in progress). The engine
  /// lets go of it first if it is the one loaded.
  Future<int> delete(String id) async {
    if (state.tasks.containsKey(id)) await cancel(id);
    final store = ref.read(modelStoreProvider);
    if (state.activeModelId == id) {
      await ref.read(localModelHostProvider).release();
    }
    final freed = await store.remove(id);
    state = state.copyWith(
      installed: await store.list(),
      activeModelId: () =>
          state.activeModelId == id ? null : state.activeModelId,
    );
    unawaited(refreshCapabilities());
    return freed;
  }

  /// Makes [id] the model on-device runs use. The next run loads it.
  Future<void> setActive(String id) async {
    if (state.installedById(id) == null) return;
    await ref.read(modelStoreProvider).setActiveModel(id);
    if (ref.mounted) state = state.copyWith(activeModelId: () => id);
  }

  Future<void> setWifiOnly(bool value) async {
    await ref.read(modelStoreProvider).setWifiOnly(value);
    state = state.copyWith(wifiOnly: value);
    if (!value) {
      _requeue(LocalModelTaskStatus.waitingForWifi);
    } else if (_running != null &&
        !await ref.read(networkStatusProvider).isUnmetered()) {
      // Restart the running download under the new rule: it waits.
      final id = _running!;
      _runningToken?.cancel('wifi only');
      _resumeAfterStop.add(id);
    }
  }

  /// Copies a picked file in. Errors are ModelDownloadException codes.
  Future<LocalModelRecord> importFile(
    File source,
    ModelImportMetadata metadata, {
    String? sha256,
  }) async {
    state = state.copyWith(importProgress: () => 0);
    try {
      final record = await ref
          .read(modelImporterProvider)
          .importFile(
            source,
            metadata,
            expectedSha256: sha256,
            onProgress: (copied, total) => state = state.copyWith(
              importProgress: () => total == 0 ? null : copied / total,
            ),
          );
      state = state.copyWith(
        installed: await ref.read(modelStoreProvider).list(),
      );
      return record;
    } finally {
      state = state.copyWith(importProgress: () => null);
      unawaited(refreshCapabilities());
    }
  }

  /// Queues a download from an https URL outside the catalog.
  Future<String> importUrl(
    String url,
    ModelImportMetadata metadata, {
    String? sha256,
  }) async {
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const ModelDownloadException(ModelDownloadErrors.insecureUrl);
    }
    final prepared = await ref
        .read(modelImporterProvider)
        .prepareUrlImport(url);
    _setTask(
      LocalModelTask(
        id: prepared.id,
        status: LocalModelTaskStatus.queued,
        urlImport: LocalUrlImport(
          url: url,
          target: prepared.target,
          metadata: metadata,
          sha256: sha256?.trim().toLowerCase(),
        ),
      ),
    );
    _pump();
    return prepared.id;
  }

  void _requeue(LocalModelTaskStatus from) {
    var any = false;
    for (final t in state.tasks.values) {
      if (t.status == from) {
        _setTask(t.copyWith(status: LocalModelTaskStatus.queued));
        any = true;
      }
    }
    if (any) _pump();
  }

  void _pump() {
    // The controller lives as long as the app; a disposed one (tests, a
    // container torn down) starts nothing.
    if (!ref.mounted || _running != null) return;
    for (final t in state.tasks.values) {
      if (t.status == LocalModelTaskStatus.queued) {
        unawaited(_run(t));
        return;
      }
    }
  }

  Future<void> _run(LocalModelTask task) async {
    final id = task.id;
    _running = id;
    final token = _runningToken = CancelToken();
    _setTask(task.copyWith(status: LocalModelTaskStatus.downloading));
    final store = ref.read(modelStoreProvider);
    try {
      final spec = state.catalog?.byId(id);
      final url = task.urlImport;
      if (spec == null && url == null) {
        _removeTask(id);
        return;
      }
      final request = url != null
          ? ModelDownloadRequest(
              url: url.url,
              target: url.target,
              sha256: url.sha256,
            )
          : ModelDownloadRequest(
              url: spec!.url,
              target: await store.fileFor(spec.id, spec.fileName),
              sha256: spec.sha256,
              sizeBytes: spec.sizeBytes,
            );
      final result = await ref
          .read(modelDownloaderProvider)
          .download(
            request,
            wifiOnly: state.wifiOnly,
            cancelToken: token,
            onProgress: (stage, received, total) {
              if (!ref.mounted) return;
              final current = state.tasks[id];
              if (current == null) return;
              _setTask(
                current.copyWith(
                  status: stage == ModelDownloadStage.verifying
                      ? LocalModelTaskStatus.verifying
                      : LocalModelTaskStatus.downloading,
                  receivedBytes: received,
                  totalBytes: total,
                ),
              );
            },
          );
      if (url != null) {
        await ref
            .read(modelImporterProvider)
            .installDownloaded(
              id,
              url.target,
              result,
              url.metadata,
              expectedSha256: url.sha256,
            );
      } else {
        await store.put(
          LocalModelRecord.fromSpec(
            spec!,
            catalogVersion: state.catalog!.catalogVersion,
            installedAt: DateTime.now(),
          ),
        );
      }
      _removeTask(id);
      final installed = await store.list();
      if (!ref.mounted) return;
      state = state.copyWith(installed: installed);
      // The first model installed is the one runs use.
      if (state.activeModelId == null) await setActive(id);
    } on ModelDownloadPaused catch (p) {
      final current = ref.mounted ? state.tasks[id] : null;
      if (current != null) {
        _setTask(
          current.copyWith(
            status: p.reason == ModelDownloadPauseReason.waitingForWifi
                ? LocalModelTaskStatus.waitingForWifi
                : LocalModelTaskStatus.paused,
          ),
        );
      }
    } on ModelDownloadException catch (e) {
      _fail(id, e.code);
    } catch (_) {
      _fail(id, ModelDownloadErrors.network);
    } finally {
      _running = null;
      _runningToken = null;
      if (_discardAfterStop.remove(id)) {
        await store.remove(id);
        _removeTask(id);
      }
      if (_resumeAfterStop.remove(id) &&
          ref.mounted &&
          state.tasks.containsKey(id)) {
        _setTask(
          state.tasks[id]!.copyWith(status: LocalModelTaskStatus.queued),
        );
      }
      unawaited(refreshCapabilities());
      _pump();
    }
  }

  void _fail(String id, String code) {
    if (!ref.mounted) return;
    final current = state.tasks[id];
    if (current == null) return;
    _setTask(
      current.copyWith(status: LocalModelTaskStatus.failed, errorCode: code),
    );
  }

  void _setTask(LocalModelTask task) {
    if (!ref.mounted) return;
    state = state.copyWith(tasks: {...state.tasks, task.id: task});
  }

  void _removeTask(String id) {
    if (!ref.mounted) return;
    state = state.copyWith(tasks: {...state.tasks}..remove(id));
  }
}

final localModelsControllerProvider =
    NotifierProvider<LocalModelsController, LocalModelsState>(
      LocalModelsController.new,
    );
