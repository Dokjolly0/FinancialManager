import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_record.dart';
import 'model_downloader.dart';
import 'model_files.dart';
import 'model_store.dart';

abstract final class ModelImportErrors {
  /// Neither a GGUF file nor a LiteRT-LM bundle.
  static const unknownFormat = 'AI_LOCAL_IMPORT_UNKNOWN_FORMAT';
}

/// What the user says about a file that isn't in the catalog.
class ModelImportMetadata {
  const ModelImportMetadata({
    required this.displayName,
    this.quantization = '',
    this.defaultContextTokens = 4096,
    this.maxContextTokens = 16384,
  });

  final String displayName;
  final String quantization;
  final int defaultContextTokens;
  final int maxContextTokens;
}

/// Installs model files from outside the catalog: a file picked on the
/// phone (copied into the model store) or one downloaded from a URL.
/// The engine comes from the file's header. Without an expected SHA-256
/// the model is installed as not verified.
class ModelImporter {
  ModelImporter({
    required ModelStore store,
    required Future<int?> Function(Directory dir) freeBytes,
    Future<String> Function(String path) hasher = sha256OfFile,
    DateTime Function()? now,
    String Function()? newId,
  }) : _store = store,
       _freeBytes = freeBytes,
       _hasher = hasher,
       _now = now ?? DateTime.now,
       _newId = newId ?? (() => 'import-${const Uuid().v4().substring(0, 8)}');

  final ModelStore _store;
  final Future<int?> Function(Directory dir) _freeBytes;
  final Future<String> Function(String path) _hasher;
  final DateTime Function() _now;
  final String Function() _newId;

  /// A fresh id and target file for a URL import, to hand to
  /// [ModelDownloader] before [installDownloaded].
  Future<({String id, File target})> prepareUrlImport(String url) async {
    final id = _newId();
    final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? 'model';
    return (id: id, target: await _store.fileFor(id, _safeName(name)));
  }

  /// Copies [source] into the store, checks its format and checksum, and
  /// registers it.
  Future<LocalModelRecord> importFile(
    File source,
    ModelImportMetadata meta, {
    String? expectedSha256,
    void Function(int copied, int total)? onProgress,
  }) async {
    final engine = await engineOfFile(source);
    if (engine == null) {
      throw const ModelDownloadException(ModelImportErrors.unknownFormat);
    }
    final id = _newId();
    final total = await source.length();
    final target = await _store.fileFor(
      id,
      _withExtension(_safeName(source.uri.pathSegments.last), engine),
    );
    await target.parent.create(recursive: true);
    final free = await _freeBytes(target.parent);
    if (free != null && free < total + ModelDownloader.spaceMargin) {
      throw ModelDownloadException(
        ModelDownloadErrors.noSpace,
        'need ${total + ModelDownloader.spaceMargin} bytes, $free free',
      );
    }

    final part = File('${target.path}.part');
    try {
      final sink = part.openWrite();
      var copied = 0;
      try {
        await for (final chunk in source.openRead()) {
          sink.add(chunk);
          copied += chunk.length;
          onProgress?.call(copied, total);
        }
      } finally {
        await sink.close();
      }
      final hash = await _hasher(part.path);
      _checkSha(hash, expectedSha256);
      await part.rename(target.path);
      return await _register(
        id,
        engine,
        target,
        total,
        hash,
        meta,
        verified: expectedSha256 != null,
        source: LocalModelSource.file,
      );
    } catch (_) {
      await _store.remove(id);
      rethrow;
    }
  }

  /// Registers a file [ModelDownloader] fetched into a target from
  /// [prepareUrlImport]; the downloader has already checked [expectedSha256]
  /// when one was given.
  Future<LocalModelRecord> installDownloaded(
    String id,
    File target,
    ModelDownloadResult result,
    ModelImportMetadata meta, {
    String? expectedSha256,
  }) async {
    final engine = await engineOfFile(target);
    if (engine == null) {
      await _store.remove(id);
      throw const ModelDownloadException(ModelImportErrors.unknownFormat);
    }
    return _register(
      id,
      engine,
      target,
      result.sizeBytes,
      result.sha256,
      meta,
      verified: expectedSha256 != null,
      source: LocalModelSource.url,
    );
  }

  Future<LocalModelRecord> _register(
    String id,
    LocalEngineKind engine,
    File file,
    int size,
    String sha256,
    ModelImportMetadata meta, {
    required bool verified,
    required LocalModelSource source,
  }) async {
    final record = LocalModelRecord(
      id: id,
      engine: engine,
      modelType: 'general',
      displayName: meta.displayName,
      quantization: meta.quantization,
      fileName: file.uri.pathSegments.last,
      sizeBytes: size,
      sha256: sha256,
      verified: verified,
      source: source,
      installedAt: _now(),
      defaultContextTokens: meta.defaultContextTokens,
      maxContextTokens: meta.maxContextTokens,
    );
    await _store.put(record);
    return record;
  }

  static void _checkSha(String actual, String? expected) {
    if (expected != null && actual != expected.trim().toLowerCase()) {
      throw ModelDownloadException(
        ModelDownloadErrors.checksum,
        'sha256 $actual, expected $expected',
      );
    }
  }

  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^[._]+'), '');
    if (trimmed.isEmpty) return 'model';
    return trimmed.length > 120
        ? trimmed.substring(trimmed.length - 120)
        : trimmed;
  }

  static String _withExtension(String name, LocalEngineKind engine) {
    final ext = engine == LocalEngineKind.llamaCpp ? '.gguf' : '.litertlm';
    return name.toLowerCase().endsWith(ext) ? name : '$name$ext';
  }
}
