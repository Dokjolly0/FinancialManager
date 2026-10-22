import 'dart:convert';
import 'dart:io';

import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';

/// Installed model files and their registry (plan.md section 33).
///
/// Layout under [root] (`<app support>/ai_models`, excluded from Android
/// backups):
/// - `registry.json`: installed models, the active one, runtime choices and
///   measured speeds per model, download preferences; written atomically
///   (temp file, then rename);
/// - `<id>/<file>`: one folder per model, with `<file>.part` while it
///   downloads.
class ModelStore {
  ModelStore(this._root);

  final Future<Directory> Function() _root;

  static const _schemaVersion = 1;

  Future<Directory> dirFor(String id) async {
    _checkId(id);
    return Directory('${(await _root()).path}/$id');
  }

  Future<File> fileFor(String id, String fileName) async {
    if (fileName.contains('/') || fileName.contains(r'\')) {
      throw ArgumentError.value(fileName, 'fileName');
    }
    return File('${(await dirFor(id)).path}/$fileName');
  }

  Future<List<LocalModelRecord>> list() async =>
      (await _read()).models.values.toList()
        ..sort((a, b) => a.installedAt.compareTo(b.installedAt));

  Future<LocalModelRecord?> get(String id) async => (await _read()).models[id];

  /// The path of [record]'s file, or null when the file is gone.
  Future<String?> pathOf(LocalModelRecord record) async {
    final f = await fileFor(record.id, record.fileName);
    return await f.exists() ? f.path : null;
  }

  Future<void> put(LocalModelRecord record) => _update((r) {
    r.models[record.id] = record;
  });

  /// Deletes the model's folder (file and any partial download) and its
  /// registry entry. Returns the bytes freed.
  Future<int> remove(String id) async {
    final dir = await dirFor(id);
    var freed = 0;
    if (await dir.exists()) {
      await for (final e in dir.list(recursive: true)) {
        if (e is File) freed += await e.length();
      }
      await dir.delete(recursive: true);
    }
    await _update((r) {
      r.models.remove(id);
      r.runtime.remove(id);
      r.speeds.removeWhere((k, _) => k.startsWith('$id:'));
      if (r.activeModelId == id) r.activeModelId = null;
    });
    return freed;
  }

  /// The model on-device runs use.
  Future<String?> get activeModelId async => (await _read()).activeModelId;

  Future<void> setActiveModel(String? id) =>
      _update((r) => r.activeModelId = id);

  Future<LocalRuntimeChoice?> runtimeChoice(String id) async =>
      (await _read()).runtime[id];

  Future<void> setRuntimeChoice(String id, LocalRuntimeChoice? choice) =>
      _update((r) {
        if (choice == null) {
          r.runtime.remove(id);
        } else {
          r.runtime[id] = choice;
        }
      });

  /// Speed measured on this phone, averaged over runs.
  Future<LocalSpeed?> speedOf(String id, LocalBackend backend) async =>
      (await _read()).speeds['$id:${backend.wire}'];

  /// Folds one measurement into the average (exponential, newer runs weigh
  /// 30%), so the estimate follows a phone that heats up or an update.
  Future<void> recordSpeed(
    String id,
    LocalBackend backend,
    LocalSpeed sample,
  ) => _update((r) {
    final key = '$id:${backend.wire}';
    final old = r.speeds[key];
    r.speeds[key] = old == null
        ? sample
        : LocalSpeed(
            prefillTps: old.prefillTps * 0.7 + sample.prefillTps * 0.3,
            decodeTps: old.decodeTps * 0.7 + sample.decodeTps * 0.3,
          );
  });

  Future<bool> get wifiOnly async => (await _read()).wifiOnly;

  Future<void> setWifiOnly(bool value) => _update((r) => r.wifiOnly = value);

  /// Registry changes run one at a time, so two writes can't lose each
  /// other's update.
  Future<void> _update(void Function(_Registry r) change) {
    final next = _pending.then((_) async {
      final r = await _read();
      change(r);
      await _write(r);
    });
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> _pending = Future.value();

  /// Completes when the registry writes started so far are done.
  Future<void> flush() => _pending;

  void _checkId(String id) {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
  }

  Future<File> get _registry async =>
      File('${(await _root()).path}/registry.json');

  Future<_Registry> _read() async {
    final f = await _registry;
    if (!await f.exists()) return _Registry();
    try {
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final models = <String, LocalModelRecord>{};
      for (final m in json['models'] as List<dynamic>? ?? const []) {
        final r = LocalModelRecord.fromJson(m as Map<String, dynamic>);
        if (r != null) models[r.id] = r;
      }
      return _Registry(
        models: models,
        wifiOnly: json['wifi_only'] as bool? ?? true,
        activeModelId: json['active_model'] as String?,
        runtime: {
          for (final e
              in (json['runtime'] as Map<String, dynamic>? ?? {}).entries)
            e.key: LocalRuntimeChoice.fromJson(e.value as Map<String, dynamic>),
        },
        speeds: {
          for (final e
              in (json['speeds'] as Map<String, dynamic>? ?? {}).entries)
            e.key: LocalSpeed.fromJson(e.value as Map<String, dynamic>),
        },
      );
    } catch (_) {
      // An unreadable registry loses the list, not the files: models can be
      // installed again without downloading if their file is intact.
      return _Registry();
    }
  }

  Future<void> _write(_Registry r) async {
    final f = await _registry;
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'schema_version': _schemaVersion,
        'wifi_only': r.wifiOnly,
        'active_model': r.activeModelId,
        'models': r.models.values.map((m) => m.toJson()).toList(),
        'runtime': {for (final e in r.runtime.entries) e.key: e.value.toJson()},
        'speeds': {
          for (final e in r.speeds.entries)
            e.key: {
              'prefill_tps': e.value.prefillTps,
              'decode_tps': e.value.decodeTps,
            },
        },
      }),
      flush: true,
    );
    await tmp.rename(f.path);
  }
}

class _Registry {
  _Registry({
    Map<String, LocalModelRecord>? models,
    this.wifiOnly = true,
    this.activeModelId,
    Map<String, LocalRuntimeChoice>? runtime,
    Map<String, LocalSpeed>? speeds,
  }) : models = models ?? {},
       runtime = runtime ?? {},
       speeds = speeds ?? {};

  final Map<String, LocalModelRecord> models;
  bool wifiOnly;
  String? activeModelId;
  final Map<String, LocalRuntimeChoice> runtime;

  /// Keyed "`model id`:`backend`".
  final Map<String, LocalSpeed> speeds;
}
