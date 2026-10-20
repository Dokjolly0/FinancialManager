import 'dart:convert';
import 'dart:io';

import '../../../../core/errors/app_error.dart';
import '../../domain/models/local_model.dart';
import '../../domain/repositories/ai_repository.dart';

/// How long an unsent result is kept before it is dropped.
const localOutboxRetention = Duration(days: 7);

/// A generated result the server hasn't accepted yet (offline, server
/// down). The server route is idempotent, so resending is always safe.
class PendingLocalResult {
  const PendingLocalResult({
    required this.userId,
    required this.analysisId,
    required this.messageId,
    required this.result,
    required this.createdAt,
  });

  /// Only this account's session may send it.
  final String userId;
  final String analysisId;
  final String messageId;
  final AiLocalResult result;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'analysis_id': analysisId,
    'message_id': messageId,
    'result': result.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static PendingLocalResult fromJson(Map<String, dynamic> json) =>
      PendingLocalResult(
        userId: json['user_id'] as String,
        analysisId: json['analysis_id'] as String,
        messageId: json['message_id'] as String,
        result: AiLocalResult.fromJson(json['result'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Keeps on-device results until the server has them: a report written on
/// the phone must not be lost because the network dropped or the session
/// expired. Items are tied to their account and expire after
/// [localOutboxRetention].
abstract interface class LocalResultOutbox {
  Future<void> add(PendingLocalResult item);

  /// Sends [userId]'s pending items; those the server accepted (or refuses
  /// for good) are removed, the others kept for the next flush.
  Future<void> flush(AiRepository repo, String userId);

  Future<List<PendingLocalResult>> pending();
}

/// Sends one item; true when it can leave the outbox.
Future<bool> _send(AiRepository repo, PendingLocalResult item) async {
  try {
    await repo.submitLocalResult(item.analysisId, item.messageId, item.result);
    return true;
  } on DomainError {
    // A domain refusal (already saved, analysis deleted) won't change on
    // retry; network errors will.
    return true;
  } catch (_) {
    return false;
  }
}

/// Shared logic over a load/save pair.
abstract class _BaseOutbox implements LocalResultOutbox {
  _BaseOutbox(this._now);

  final DateTime Function() _now;
  bool _flushing = false;

  Future<List<PendingLocalResult>> load();
  Future<void> save(List<PendingLocalResult> items);

  List<PendingLocalResult> _fresh(List<PendingLocalResult> items) => items
      .where((i) => _now().difference(i.createdAt) < localOutboxRetention)
      .toList();

  @override
  Future<void> add(PendingLocalResult item) async {
    final items = _fresh(await load())
      ..removeWhere((i) => i.messageId == item.messageId);
    await save([...items, item]);
  }

  @override
  Future<void> flush(AiRepository repo, String userId) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final items = _fresh(await load());
      final kept = <PendingLocalResult>[];
      for (final item in items) {
        if (item.userId != userId || !await _send(repo, item)) kept.add(item);
      }
      await save(kept);
    } finally {
      _flushing = false;
    }
  }

  @override
  Future<List<PendingLocalResult>> pending() async => _fresh(await load());
}

/// The outbox in memory; used by tests and as a fallback.
class MemoryLocalResultOutbox extends _BaseOutbox {
  MemoryLocalResultOutbox({DateTime Function()? now})
    : super(now ?? DateTime.now);

  List<PendingLocalResult> _items = [];

  @override
  Future<List<PendingLocalResult>> load() async => List.of(_items);

  @override
  Future<void> save(List<PendingLocalResult> items) async =>
      _items = List.of(items);
}

/// The outbox in a JSON file, written atomically (temp file, then rename).
/// [file] is resolved lazily (path_provider is asynchronous).
class FileLocalResultOutbox extends _BaseOutbox {
  FileLocalResultOutbox(this._file, {DateTime Function()? now})
    : super(now ?? DateTime.now);

  final Future<File> Function() _file;

  @override
  Future<List<PendingLocalResult>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
      return raw
          .map((e) => PendingLocalResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<PendingLocalResult> items) async {
    final file = await _file();
    if (items.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(items.map((i) => i.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(file.path);
  }
}
