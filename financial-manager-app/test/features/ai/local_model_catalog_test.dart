import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/domain/models/device_capabilities.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/models/local_model_catalog.dart';

void main() {
  final raw =
      jsonDecode(File('assets/ai/local_models.json').readAsStringSync())
          as Map<String, dynamic>;
  final catalog = LocalModelCatalog.fromJson(raw);
  final rawModels = (raw['models'] as List).cast<Map<String, dynamic>>();

  group('bundled catalog', () {
    test('versions and unique ids', () {
      expect(catalog.schemaVersion, 1);
      expect(catalog.catalogVersion, greaterThanOrEqualTo(1));
      expect(catalog.models, isNotEmpty);
      final ids = catalog.models.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$')));
      }
    });

    test('URLs and checksums are pinned', () {
      for (final m in catalog.models) {
        final url = RegExp(
          r'^https://huggingface\.co/[\w.-]+/[\w.-]+/resolve/([0-9a-f]{40})/([\w.-]+)$',
        ).firstMatch(m.url);
        expect(url, isNotNull, reason: '${m.id}: ${m.url}');
        expect(url!.group(1), m.revision, reason: m.id);
        expect(m.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: m.id);
        expect(m.sizeBytes, greaterThan(100 * 1024 * 1024), reason: m.id);
      }
    });

    test('engine, format, file and quantization agree', () {
      for (final m in catalog.models) {
        switch (m.engine) {
          case LocalEngineKind.litertLm:
            expect(m.format, 'litertlm', reason: m.id);
            expect(m.fileName, endsWith('.litertlm'), reason: m.id);
          case LocalEngineKind.llamaCpp:
            expect(m.format, 'gguf', reason: m.id);
            expect(m.fileName, endsWith('.gguf'), reason: m.id);
            expect(
              m.quantization,
              matches(RegExp(r'^(I?Q\d|F16|BF16)')),
              reason: m.id,
            );
        }
        expect(m.quantization, isNotEmpty, reason: m.id);
        expect(m.modelType, isNotEmpty, reason: m.id);
      }
    });

    test('backends follow the prototype', () {
      for (final m in catalog.models) {
        expect(m.backends, isNotEmpty, reason: m.id);
        expect(m.backends, isNot(contains(LocalBackend.npu)), reason: m.id);
        // llama.cpp's GPU (Vulkan) crashed on Adreno: CPU only.
        if (m.engine == LocalEngineKind.llamaCpp) {
          expect(m.backends, [LocalBackend.cpu], reason: m.id);
        }
        // LiteRT-LM's float16 default writes wrong digits on the GPU.
        if (m.backends.contains(LocalBackend.gpu)) {
          expect(m.gpuActivation, 'float32', reason: m.id);
        }
        for (final b in m.backends) {
          final s = m.speed[b];
          expect(s, isNotNull, reason: '${m.id} speed on ${b.wire}');
          expect(s!.prefillTps, greaterThan(0));
          expect(s.decodeTps, greaterThan(0));
        }
      }
    });

    test('memory, context and token limits are sane', () {
      for (final m in catalog.models) {
        expect(m.ramMinMb, greaterThan(0), reason: m.id);
        expect(m.ramMinMb, lessThanOrEqualTo(m.ramRecommendedMb), reason: m.id);
        expect(
          m.contextDefault,
          inInclusiveRange(2048, m.contextMax),
          reason: m.id,
        );
        expect(m.contextMax, lessThanOrEqualTo(32768), reason: m.id);
        if (m.contextMaxCpu != null) {
          expect(
            m.contextMaxCpu,
            lessThanOrEqualTo(m.contextMax),
            reason: m.id,
          );
        }
        // LiteRT-LM on the CPU was killed for memory at 16k.
        if (m.engine == LocalEngineKind.litertLm &&
            m.backends.contains(LocalBackend.cpu)) {
          expect(m.contextMaxCpu, lessThanOrEqualTo(8192), reason: m.id);
        }
        expect(m.tokenFactor, inInclusiveRange(1.0, 3.0), reason: m.id);
      }
    });

    test('license and notes in both languages', () {
      for (final (i, m) in catalog.models.indexed) {
        expect(m.license.id, isNotEmpty, reason: m.id);
        expect(m.license.url, startsWith('https://'), reason: m.id);
        if (m.license.gated) {
          expect(m.license.requiresAcceptance, isTrue, reason: m.id);
        }
        expect(m.notes.keys, containsAll(['it', 'en']), reason: m.id);
        expect(m.noteFor('it'), isNotEmpty);
        expect(m.noteFor('fr'), m.notes['en']);
        expect(rawModels[i]['license'], contains('gated'));
      }
    });

    test('exactly one recommended model', () {
      expect(catalog.models.where((m) => m.recommended), hasLength(1));
    });
  });

  group('RAM fit', () {
    const gib = 1024 * 1024 * 1024;
    final e2b = catalog.byId('gemma4-e2b-litert')!;
    final e4b = catalog.byId('gemma4-e4b-litert')!;

    test('catalog models on the reference and smaller phones', () {
      // A 12 GB Galaxy S26 Ultra reports 11.6 GB.
      const s26 = 11623399424;
      expect(ramFitForSpec(e2b, s26), RamFit.fits);
      expect(ramFitForSpec(e4b, s26), RamFit.fits);
      expect(ramFitForSpec(e4b, 8 * gib), RamFit.tight);
      expect(ramFitForSpec(e2b, 4 * gib), RamFit.insufficient);
      expect(ramFitForSpec(e2b, null), RamFit.unknown);
    });

    test('imported files', () {
      expect(
        estimateRamFit(
          fileBytes: 2 * gib,
          contextTokens: 4096,
          totalMemBytes: 12 * gib,
        ),
        RamFit.fits,
      );
      expect(
        estimateRamFit(
          fileBytes: 4 * gib,
          contextTokens: 16384,
          totalMemBytes: 12 * gib,
        ),
        RamFit.tight,
      );
      expect(
        estimateRamFit(
          fileBytes: 8 * gib,
          contextTokens: 8192,
          totalMemBytes: 12 * gib,
        ),
        RamFit.insufficient,
      );
    });
  });
}
