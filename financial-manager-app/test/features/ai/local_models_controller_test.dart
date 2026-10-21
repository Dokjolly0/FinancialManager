import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/device_capabilities_source.dart';
import 'package:financialmanager/features/ai/data/local/model_downloader.dart';
import 'package:financialmanager/features/ai/data/local/model_importer.dart';
import 'package:financialmanager/features/ai/data/local/model_store.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/device_capabilities.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_catalog.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';
import 'package:financialmanager/features/ai/presentation/view_models/local_models_controller.dart';

import 'fakes/fake_model_server.dart';

class _FakeCapabilities implements DeviceCapabilitiesSource {
  @override
  Future<DeviceCapabilities?> read() async => const DeviceCapabilities(
    totalMemBytes: 11623399424,
    freeStorageBytes: 100 * 1024 * 1024 * 1024,
  );
}

Map<String, dynamic> _spec(String id, List<int> bytes) => {
  'id': id,
  'family': 'gemma4',
  'display_name': 'Model $id',
  'engine': 'llama_cpp',
  'format': 'gguf',
  'model_type': 'gemma4',
  'quantization': 'Q4_K_M',
  'url':
      'https://huggingface.co/org/$id/resolve/0123456789abcdef0123456789abcdef01234567/$id.gguf',
  'revision': '0123456789abcdef0123456789abcdef01234567',
  'sha256': sha256Hex(bytes),
  'size_bytes': bytes.length,
  'ram_min_mb': 6144,
  'ram_recommended_mb': 8192,
  'context_default': 8192,
  'context_max': 16384,
  'backends': ['cpu'],
  'token_factor': 1.59,
  'speed': {
    'cpu': {'prefill_tps': 49, 'decode_tps': 12},
  },
  'notes': {'it': 'nota', 'en': 'note'},
  'license': {'id': 'apache-2.0', 'url': 'https://example.com', 'gated': false},
};

void main() {
  late Directory root;
  late FakeModelServer server;
  late FakeNetworkStatus network;
  late ProviderContainer container;
  late ModelStore store;
  final bytes = fakeModelBytes(8000);

  ProviderContainer make() {
    store = ModelStore(() async => root);
    return ProviderContainer(
      overrides: [
        localModelCatalogProvider.overrideWith(
          (ref) async => LocalModelCatalog.fromJson({
            'schema_version': 1,
            'catalog_version': 3,
            'models': [_spec('alpha', bytes), _spec('beta', bytes)],
          }),
        ),
        modelStoreProvider.overrideWithValue(store),
        networkStatusProvider.overrideWithValue(network),
        deviceCapabilitiesSourceProvider.overrideWithValue(_FakeCapabilities()),
        modelDownloaderProvider.overrideWithValue(
          ModelDownloader(
            dio: fakeDio(server),
            network: network,
            freeBytes: (_) async => null,
            progressInterval: Duration.zero,
          ),
        ),
        modelImporterProvider.overrideWithValue(
          ModelImporter(store: store, freeBytes: (_) async => null),
        ),
      ],
    );
  }

  LocalModelsState state() => container.read(localModelsControllerProvider);
  LocalModelsController ctl() =>
      container.read(localModelsControllerProvider.notifier);

  Future<void> until(bool Function() done) async {
    final sw = Stopwatch()..start();
    while (!done()) {
      if (sw.elapsed > const Duration(seconds: 5)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> loaded() async {
    container.listen(localModelsControllerProvider, (_, _) {});
    await until(() => !state().isLoading);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fm_ctl_');
    server = FakeModelServer(bytes);
    network = FakeNetworkStatus();
    container = make();
  });

  tearDown(() async {
    // Let the work after a finished download (registry, active model) end
    // before the container goes.
    await until(() => state().tasks.values.every((t) => !t.isActive));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    container.dispose();
    await store.flush();
    await root.delete(recursive: true);
  });

  test('downloads run one at a time and install verified records', () async {
    await loaded();
    expect(state().catalog!.models, hasLength(2));
    expect(state().ramFit(state().catalog!.byId('alpha')!), RamFit.fits);

    var concurrent = 0;
    var maxConcurrent = 0;
    server.onChunk = (n) {
      // 8000 bytes in 1000-byte chunks: 0 is the first, 7 the last.
      if (n == 0 && ++concurrent > maxConcurrent) maxConcurrent = concurrent;
      if (n == 7) concurrent--;
    };
    ctl().download('alpha');
    ctl().download('beta');
    expect(state().tasks['beta']!.status, LocalModelTaskStatus.queued);

    await until(() => state().installed.length == 2);
    expect(maxConcurrent, 1);
    expect(state().tasks, isEmpty);
    final alpha = state().installedById('alpha')!;
    expect(alpha.verified, isTrue);
    expect(alpha.source, LocalModelSource.catalog);
    expect(alpha.catalogVersion, 3);
    expect(alpha.tokenFactor, 1.59);
  });

  test('waits for Wi-Fi and resumes by itself when it comes back', () async {
    network.unmetered = false;
    await loaded();
    ctl().download('alpha');
    await until(
      () =>
          state().tasks['alpha']?.status == LocalModelTaskStatus.waitingForWifi,
    );
    expect(server.requests, isEmpty);

    network.set(true);
    await until(() => state().installedById('alpha') != null);
  });

  test('turning Wi-Fi only off releases waiting downloads', () async {
    network.unmetered = false;
    await loaded();
    ctl().download('alpha');
    await until(
      () =>
          state().tasks['alpha']?.status == LocalModelTaskStatus.waitingForWifi,
    );
    await ctl().setWifiOnly(false);
    await until(() => state().installedById('alpha') != null);
    expect(state().wifiOnly, isFalse);
  });

  test(
    'pause keeps the partial file, which shows up after a restart',
    () async {
      await loaded();
      server.onChunk = (n) {
        if (n == 3) ctl().pause('alpha');
      };
      ctl().download('alpha');
      await until(
        () => state().tasks['alpha']?.status == LocalModelTaskStatus.paused,
      );
      final kept = state().tasks['alpha']!.receivedBytes;
      expect(kept, greaterThan(0));

      // A new app session finds the partial file.
      container.dispose();
      container = make();
      await loaded();
      final task = state().tasks['alpha']!;
      expect(task.status, LocalModelTaskStatus.paused);
      expect(task.receivedBytes, kept);
      expect(task.totalBytes, bytes.length);

      server.onChunk = null;
      ctl().resume('alpha');
      await until(() => state().installedById('alpha') != null);
      expect(server.cdnRequests.last.headers['Range'], 'bytes=$kept-');
    },
  );

  test(
    'a failure keeps its code until retried; cancel and delete clean up',
    () async {
      await loaded();
      server.hubStatus = 403;
      ctl().download('alpha');
      await until(
        () => state().tasks['alpha']?.status == LocalModelTaskStatus.failed,
      );
      expect(state().tasks['alpha']!.errorCode, ModelDownloadErrors.gated);

      server.hubStatus = null;
      ctl().download('alpha');
      await until(() => state().installedById('alpha') != null);

      server.onChunk = (n) {
        if (n == 2) ctl().cancel('beta');
      };
      ctl().download('beta');
      await until(() => !state().tasks.containsKey('beta'));
      expect(Directory('${root.path}/beta').existsSync(), isFalse);

      expect(await ctl().delete('alpha'), bytes.length);
      expect(state().installed, isEmpty);
      expect(Directory('${root.path}/alpha').existsSync(), isFalse);
    },
  );

  test(
    'URL imports go through the queue and are registered by header',
    () async {
      await loaded();
      final id = await ctl().importUrl(
        'https://huggingface.co/org/other/resolve/main/other.gguf',
        const ModelImportMetadata(displayName: 'Other', quantization: 'Q6_K'),
        sha256: sha256Hex(bytes),
      );
      await until(() => state().installedById(id) != null);
      final r = state().installedById(id)!;
      expect(r.source, LocalModelSource.url);
      expect(r.verified, isTrue);
      expect(r.label, 'Other · Q6_K');

      expect(
        () => ctl().importUrl(
          'http://example.com/m.gguf',
          const ModelImportMetadata(displayName: 'x'),
        ),
        throwsA(isA<ModelDownloadException>()),
      );
    },
  );
}
