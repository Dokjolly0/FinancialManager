import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/model_downloader.dart';
import 'package:financialmanager/features/ai/data/local/model_files.dart';
import 'package:financialmanager/features/ai/data/local/model_importer.dart';
import 'package:financialmanager/features/ai/data/local/model_store.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_record.dart';

import 'fakes/fake_model_server.dart';

LocalModelRecord _record(String id, {DateTime? at}) => LocalModelRecord(
  id: id,
  engine: LocalEngineKind.llamaCpp,
  modelType: 'qwen35',
  displayName: 'Qwen3.5 4B',
  quantization: 'Q4_K_M',
  fileName: 'model.gguf',
  sizeBytes: 10,
  sha256: 'a' * 64,
  verified: true,
  source: LocalModelSource.catalog,
  installedAt: at ?? DateTime.utc(2026, 10, 21),
  defaultContextTokens: 8192,
  maxContextTokens: 16384,
  backends: const [LocalBackend.cpu],
  tokenFactor: 1.57,
  catalogVersion: 1,
);

void main() {
  late Directory root;
  late ModelStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fm_store_');
    store = ModelStore(() async => root);
  });

  tearDown(() => root.delete(recursive: true));

  group('ModelStore', () {
    test('registry round trip, survives a new instance', () async {
      await store.put(_record('b', at: DateTime.utc(2026, 10, 22)));
      await store.put(_record('a'));
      expect(await store.wifiOnly, isTrue);
      await store.setWifiOnly(false);

      final again = ModelStore(() async => root);
      final list = await again.list();
      expect(list.map((r) => r.id), ['a', 'b']);
      expect(list.first.tokenFactor, 1.57);
      expect(list.first.label, 'Qwen3.5 4B · Q4_K_M');
      expect(await again.wifiOnly, isFalse);
      expect(File('${root.path}/registry.json.tmp').existsSync(), isFalse);
    });

    test('concurrent updates are not lost', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++) store.put(_record('m$i')),
        store.setWifiOnly(false),
      ]);
      expect(await store.list(), hasLength(10));
      expect(await store.wifiOnly, isFalse);
    });

    test('remove deletes the folder, partial files included', () async {
      final f = await store.fileFor('a', 'model.gguf');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(List.filled(10, 1));
      await File('${f.path}.part').writeAsBytes(List.filled(5, 1));
      await store.put(_record('a'));

      expect(await store.pathOf(_record('a')), f.path);
      expect(await store.remove('a'), 15);
      expect(await store.list(), isEmpty);
      expect(await f.parent.exists(), isFalse);
      expect(await store.pathOf(_record('a')), isNull);
    });

    test('a corrupt registry reads as empty', () async {
      await File('${root.path}/registry.json').writeAsString('{not json');
      expect(await store.list(), isEmpty);
      await store.put(_record('a'));
      expect(await store.list(), hasLength(1));
    });

    test('ids and file names cannot escape the store', () async {
      expect(() => store.dirFor('../x'), throwsArgumentError);
      expect(() => store.dirFor('A'), throwsArgumentError);
      expect(() => store.fileFor('a', '../registry.json'), throwsArgumentError);
    });

    test('toInstalled points the engines at the file', () {
      final m = _record('a').toInstalled('/x/model.gguf');
      expect(m.path, '/x/model.gguf');
      expect(m.engine, LocalEngineKind.llamaCpp);
      expect(m.maxContextTokens, 16384);
    });
  });

  group('file headers', () {
    test('GGUF and LiteRT-LM are recognized', () {
      expect(
        engineFromHeader('GGUF\x03\x00\x00\x00'.codeUnits),
        LocalEngineKind.llamaCpp,
      );
      expect(engineFromHeader('LITERTLM'.codeUnits), LocalEngineKind.litertLm);
      expect(engineFromHeader('PK\x03\x04'.codeUnits), isNull);
      expect(engineFromHeader(const []), isNull);
    });

    test('sha256OfFile matches the in-memory digest', () async {
      final bytes = fakeModelBytes(5 * 1024 * 1024 + 7);
      final f = File('${root.path}/big.bin')..writeAsBytesSync(bytes);
      expect(await sha256OfFile(f.path), sha256Hex(bytes));
    });
  });

  group('ModelImporter', () {
    late Directory picked;
    var ids = 0;

    ModelImporter importer({int? free}) => ModelImporter(
      store: store,
      freeBytes: (_) async => free,
      now: () => DateTime.utc(2026, 10, 21),
      newId: () => 'import-${ids++}',
    );

    setUp(() async {
      picked = await Directory.systemTemp.createTemp('fm_pick_');
    });

    tearDown(() => picked.delete(recursive: true));

    test('copies a GGUF file in, unverified without a checksum', () async {
      final bytes = fakeModelBytes(20000);
      final src = File('${picked.path}/My Model (Q5).gguf')
        ..writeAsBytesSync(bytes);
      final progress = <int>[];

      final r = await importer().importFile(
        src,
        const ModelImportMetadata(
          displayName: 'My Model',
          quantization: 'Q5_K_M',
        ),
        onProgress: (copied, _) => progress.add(copied),
      );

      expect(r.engine, LocalEngineKind.llamaCpp);
      expect(r.verified, isFalse);
      expect(r.source, LocalModelSource.file);
      expect(r.modelType, 'general');
      expect(r.sha256, sha256Hex(bytes));
      expect(r.fileName, 'My_Model__Q5_.gguf');
      expect(progress.last, bytes.length);
      final path = await store.pathOf(r);
      expect(await File(path!).readAsBytes(), bytes);
      expect(await src.exists(), isTrue, reason: 'the original stays');
      expect((await store.list()).single.id, r.id);
    });

    test(
      'a matching checksum marks it verified; a wrong one leaves nothing',
      () async {
        final bytes = fakeModelBytes(3000, magic: 'LITERTLM');
        final src = File('${picked.path}/bundle')..writeAsBytesSync(bytes);

        final ok = await importer().importFile(
          src,
          const ModelImportMetadata(displayName: 'Bundle'),
          expectedSha256: sha256Hex(bytes).toUpperCase(),
        );
        expect(ok.verified, isTrue);
        expect(ok.engine, LocalEngineKind.litertLm);
        expect(ok.fileName, 'bundle.litertlm');

        await expectLater(
          importer().importFile(
            src,
            const ModelImportMetadata(displayName: 'Bundle'),
            expectedSha256: 'c' * 64,
          ),
          throwsA(
            isA<ModelDownloadException>().having(
              (e) => e.code,
              'code',
              ModelDownloadErrors.checksum,
            ),
          ),
        );
        expect((await store.list()).map((r) => r.id), [ok.id]);
        expect(root.listSync().whereType<Directory>(), hasLength(1));
      },
    );

    test('unknown formats and missing space are refused', () async {
      final zip = File('${picked.path}/x.zip')
        ..writeAsBytesSync('PK\x03\x04data'.codeUnits);
      await expectLater(
        importer().importFile(zip, const ModelImportMetadata(displayName: 'x')),
        throwsA(
          isA<ModelDownloadException>().having(
            (e) => e.code,
            'code',
            ModelImportErrors.unknownFormat,
          ),
        ),
      );

      final gguf = File('${picked.path}/m.gguf')
        ..writeAsBytesSync(fakeModelBytes(100));
      await expectLater(
        importer(
          free: 10,
        ).importFile(gguf, const ModelImportMetadata(displayName: 'm')),
        throwsA(
          isA<ModelDownloadException>().having(
            (e) => e.code,
            'code',
            ModelDownloadErrors.noSpace,
          ),
        ),
      );
      expect(await store.list(), isEmpty);
    });
  });
}
