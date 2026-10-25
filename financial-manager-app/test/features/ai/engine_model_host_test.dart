import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/device_capabilities_source.dart';
import 'package:financialmanager/features/ai/data/local/engine_model_host.dart';
import 'package:financialmanager/features/ai/data/local/model_benchmark.dart';
import 'package:financialmanager/features/ai/data/local/model_store.dart';
import 'package:financialmanager/features/ai/domain/local/local_llm_engine.dart';
import 'package:financialmanager/features/ai/domain/models/device_capabilities.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';

import 'fakes/fake_local_engine.dart';

class _Device implements DeviceCapabilitiesSource {
  DeviceCapabilities? caps = const DeviceCapabilities(thermalStatus: 0);

  @override
  Future<DeviceCapabilities?> read() async => caps;
}

LocalModelRecord _record(
  String id, {
  LocalEngineKind engine = LocalEngineKind.litertLm,
  List<LocalBackend> backends = const [LocalBackend.gpu, LocalBackend.cpu],
  int? cpuMax = 8192,
}) => LocalModelRecord(
  id: id,
  engine: engine,
  modelType: 'gemma4',
  displayName: 'Gemma 4 E2B',
  quantization: 'int4/int8',
  fileName: 'm.bin',
  sizeBytes: 4,
  sha256: 'a' * 64,
  verified: true,
  source: LocalModelSource.catalog,
  installedAt: DateTime.utc(2026, 10, 21),
  defaultContextTokens: 16384,
  maxContextTokens: 16384,
  maxContextTokensCpu: cpuMax,
  backends: backends,
  tokenFactor: 1.59,
);

void main() {
  late Directory root;
  late ModelStore store;
  late FakeLocalEngine litert;
  late FakeLocalEngine llama;
  late _Device device;

  EngineModelHost host({Duration idle = const Duration(minutes: 5)}) =>
      EngineModelHost(
        store: store,
        engines: {
          LocalEngineKind.litertLm: litert,
          LocalEngineKind.llamaCpp: llama,
        },
        device: device,
        idleTimeout: idle,
      );

  Future<void> install(LocalModelRecord r) async {
    final f = await store.fileFor(r.id, r.fileName);
    await f.parent.create(recursive: true);
    await f.writeAsBytes([1, 2, 3, 4]);
    await store.put(r);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fm_host_');
    store = ModelStore(() async => root);
    litert = FakeLocalEngine(kind: LocalEngineKind.litertLm);
    llama = FakeLocalEngine(kind: LocalEngineKind.llamaCpp);
    device = _Device();
  });

  tearDown(() async {
    await store.flush();
    await root.delete(recursive: true);
  });

  group('paramsFor', () {
    test(
      'defaults: first backend, model context, 1024 out, low temperature',
      () {
        final p = EngineModelHost.paramsFor(_record('a'), null);
        expect(p.backend, LocalBackend.gpu);
        expect(p.contextTokens, 16384);
        expect(p.maxOutputTokens, 1024);
        expect(p.temperature, 0.2);
      },
    );

    test('LiteRT-LM on the CPU is held to its lower context', () {
      final p = EngineModelHost.paramsFor(
        _record('a'),
        const LocalRuntimeChoice(
          backend: LocalBackend.cpu,
          contextTokens: 16384,
        ),
      );
      expect(p.backend, LocalBackend.cpu);
      expect(p.contextTokens, 8192);
    });

    test('choices outside what the model offers are clamped', () {
      final p = EngineModelHost.paramsFor(
        _record(
          'a',
          engine: LocalEngineKind.llamaCpp,
          backends: const [LocalBackend.cpu],
        ),
        const LocalRuntimeChoice(
          backend: LocalBackend.gpu,
          contextTokens: 100,
          maxOutputTokens: 5000,
          temperature: 3,
        ),
      );
      expect(p.backend, LocalBackend.cpu);
      expect(p.contextTokens, 2048);
      expect(p.maxOutputTokens, 1024, reason: 'at most half the context');
      expect(p.temperature, 1.0);
    });
  });

  group('acquire', () {
    test('no active model, or its file gone: model missing', () async {
      final h = host();
      await expectLater(
        h.acquire(),
        throwsA(
          isA<LocalEngineException>().having(
            (e) => e.code,
            'code',
            LocalErrorCodes.modelMissing,
          ),
        ),
      );
      await store.put(_record('a'));
      await store.setActiveModel('a');
      await expectLater(
        h.acquire(),
        throwsA(
          isA<LocalEngineException>().having(
            (e) => e.code,
            'code',
            LocalErrorCodes.modelMissing,
          ),
        ),
      );
    });

    test('a hot phone is refused before loading', () async {
      await install(_record('a'));
      await store.setActiveModel('a');
      device.caps = const DeviceCapabilities(thermalStatus: 3);
      await expectLater(
        host().acquire(),
        throwsA(
          isA<LocalEngineException>().having(
            (e) => e.code,
            'code',
            LocalErrorCodes.tooHot,
          ),
        ),
      );
      expect(litert.loads, isEmpty);
    });

    test('loads once, reuses, reloads on a new model or context', () async {
      await install(_record('a'));
      await install(
        _record(
          'b',
          engine: LocalEngineKind.llamaCpp,
          backends: const [LocalBackend.cpu],
        ),
      );
      await store.setActiveModel('a');
      final h = host();

      final s1 = await h.acquire();
      final s2 = await h.acquire();
      expect(litert.loads, hasLength(1));
      expect(identical(s1.engine, s2.engine), isTrue);
      expect(s1.model.path, endsWith('m.bin'));
      expect(s1.model.modelType, 'gemma4');

      await store.setRuntimeChoice(
        'a',
        const LocalRuntimeChoice(contextTokens: 8192),
      );
      await h.acquire();
      expect(litert.loads, hasLength(2));
      expect(litert.loads.last.$2.contextTokens, 8192);

      // Only the output limit changed: no reload.
      await store.setRuntimeChoice(
        'a',
        const LocalRuntimeChoice(contextTokens: 8192, maxOutputTokens: 512),
      );
      final s3 = await h.acquire();
      expect(litert.loads, hasLength(2));
      expect(s3.params.maxOutputTokens, 512);

      await store.setActiveModel('b');
      final s4 = await h.acquire();
      expect(litert.unloads, 2, reason: 'one per reload, then the switch');
      expect(llama.loads, hasLength(1));
      expect(s4.engine, same(llama));
    });

    test(
      'a requested model is used while installed, else the active',
      () async {
        await install(_record('a'));
        await install(
          _record(
            'b',
            engine: LocalEngineKind.llamaCpp,
            backends: const [LocalBackend.cpu],
          ),
        );
        await store.setActiveModel('a');
        final h = host();
        expect((await h.acquire(modelId: 'b')).model.id, 'b');
        expect(llama.loads, hasLength(1));
        expect((await h.acquire(modelId: 'gone')).model.id, 'a');
        expect((await h.acquire()).model.id, 'a');
      },
    );

    test('the session reports where the model really runs', () async {
      await install(_record('a'));
      await store.setActiveModel('a');
      litert.runsOn = LocalBackend.cpu;
      final s = await host().acquire();
      expect(litert.loads.single.$2.backend, LocalBackend.gpu);
      expect(s.params.backend, LocalBackend.cpu);
    });
  });

  test('unloads when idle, but not while generating', () async {
    await install(_record('a'));
    await store.setActiveModel('a');
    final h = host(idle: const Duration(milliseconds: 60));
    await h.acquire();

    // A generation longer than the idle timeout keeps the model loaded.
    litert.delay = const Duration(milliseconds: 150);
    final done = litert
        .generate(
          const LocalChatRequest(
            system: 's',
            messages: [LocalChatMessage(role: 'user', content: 'q')],
            params: LocalRuntimeParams(contextTokens: 4096),
          ),
        )
        .drain<void>();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(litert.isGenerating, isTrue);
    expect(litert.isLoaded, isTrue);

    await done;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(litert.isLoaded, isFalse);
  });

  test('release and memory pressure unload; speeds are averaged', () async {
    await install(_record('a'));
    await store.setActiveModel('a');
    final h = host();
    final s = await h.acquire();

    h.recordSpeed(
      s,
      const LocalGenStats(
        promptTokens: 3000,
        outputTokens: 301,
        prefillMs: 5000,
        decodeMs: 10000,
      ),
    );
    await store.flush();
    var speed = await store.speedOf('a', LocalBackend.gpu);
    expect(speed!.prefillTps, 600);
    expect(speed.decodeTps, 30);

    h.recordSpeed(
      s,
      const LocalGenStats(
        promptTokens: 3000,
        outputTokens: 101,
        prefillMs: 10000,
        decodeMs: 10000,
      ),
    );
    await store.flush();
    speed = await store.speedOf('a', LocalBackend.gpu);
    expect(speed!.prefillTps, closeTo(600 * 0.7 + 300 * 0.3, 1e-9));
    expect(speed.decodeTps, closeTo(30 * 0.7 + 10 * 0.3, 1e-9));

    await h.onMemoryPressure();
    expect(litert.isLoaded, isFalse);
    await h.acquire();
    await h.release();
    expect(litert.isLoaded, isFalse);
  });

  test('the benchmark runs about 1,000 tokens and records the speed', () async {
    await install(_record('a'));
    await store.setActiveModel('a');
    final h = host();
    final speed = await ModelBenchmark(h).run();
    expect(speed.decodeTps, greaterThan(0));
    final req = litert.lastRequest!;
    expect(req.params.maxOutputTokens, 128);
    expect(ModelBenchmark.prompt.length, inInclusiveRange(2000, 3000));
    expect(req.messages.single.content, ModelBenchmark.prompt);
    await store.flush();
    expect(await store.speedOf('a', LocalBackend.gpu), isNotNull);
  });

  test('run warnings', () {
    expect(runWarnings(null), isEmpty);
    expect(runWarnings(const DeviceCapabilities(thermalStatus: 2)), {
      LocalRunWarning.warm,
    });
    expect(
      runWarnings(const DeviceCapabilities(thermalStatus: 3)),
      isEmpty,
      reason: 'refused instead',
    );
    expect(
      runWarnings(
        const DeviceCapabilities(
          batteryPercent: 10,
          charging: false,
          lowMemory: true,
        ),
      ),
      {LocalRunWarning.lowBattery, LocalRunWarning.lowMemory},
    );
    expect(
      runWarnings(const DeviceCapabilities(batteryPercent: 10, charging: true)),
      isEmpty,
    );
  });
}
