import 'dart:convert';
import 'dart:io';

import '../../../../core/errors/app_error.dart';
import '../../domain/models/local_model.dart';
import '../../domain/repositories/ai_repository.dart';

/// A generated result the server hasn't accepted yet (offline, server
/// down, or refused). The server route is idempotent, so resending is
/// always safe.
class PendingLocalResult {
  const PendingLocalResult({
    required this.userId,
    required this.analysisId,
    required this.messageId,
    required this.result,
    required this.createdAt,
    this.ownerName,
    this.modelLabel,
    this.isReport = true,
    this.refusedCode,
  });

  /// Only this account may send or delete it; anyone using the app on the
  /// phone may read it.
  final String userId;
  final String analysisId;
  final String messageId;
  final AiLocalResult result;
  final DateTime createdAt;

  /// Who wrote it and with which model, for the list of unsent results.
  final String? ownerName;
  final String? modelLabel;

  /// A report, or the answer to a follow-up question.
  final bool isReport;

  /// The server's error code when it refused the result (the analysis was
  /// deleted meanwhile, the answer was already saved differently). Such an
  /// item is no longer sent by itself: its owner resends or deletes it.
  final String? refusedCode;

  PendingLocalResult copyWith({String? Function()? refusedCode}) =>
      PendingLocalResult(
        userId: userId,
        analysisId: analysisId,
        messageId: messageId,
        result: result,
        createdAt: createdAt,
        ownerName: ownerName,
        modelLabel: modelLabel,
        isReport: isReport,
        refusedCode: refusedCode == null ? this.refusedCode : refusedCode(),
      );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'analysis_id': analysisId,
    'message_id': messageId,
    'result': result.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'owner_name': ?ownerName,
    'model_label': ?modelLabel,
    'is_report': isReport,
    'refused_code': ?refusedCode,
  };

  static PendingLocalResult fromJson(Map<String, dynamic> json) =>
      PendingLocalResult(
        userId: json['user_id'] as String,
        analysisId: json['analysis_id'] as String,
        messageId: json['message_id'] as String,
        result: AiLocalResult.fromJson(json['result'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['created_at'] as String),
        ownerName: json['owner_name'] as String?,
        modelLabel: json['model_label'] as String?,
        isReport: json['is_report'] as bool? ?? true,
        refusedCode: json['refused_code'] as String?,
      );
}

/// What sending one item did.
enum LocalResendOutcome { sent, refused, failed, notOwner }

/// Keeps on-device results until the server has them: a report written on
/// the phone must not be lost because the network dropped or the session
/// expired. Items never expire: they stay until the server accepts them or
/// their owner deletes them. Anyone using the app on the phone can read
/// them; only their owner's session sends or deletes them.
abstract interface class LocalResultOutbox {
  Future<void> add(PendingLocalResult item);

  /// Sends [userId]'s pending items that the server hasn't refused; those
  /// accepted leave, refused ones stay marked, the others wait for the
  /// next flush.
  Future<void> flush(AiRepository repo, String userId);

  /// Sends one item now, refused before or not, if [userId] owns it.
  Future<LocalResendOutcome> resend(
    AiRepository repo,
    String userId,
    String messageId,
  );

  /// Deletes one item if [userId] owns it; false otherwise.
  Future<bool> remove(String userId, String messageId);

  /// Every item, of every account, oldest first.
  Future<List<PendingLocalResult>> pending();
}

/// Shared logic over a load/save pair.
abstract class _BaseOutbox implements LocalResultOutbox {
  bool _flushing = false;

  Future<List<PendingLocalResult>> load();
  Future<void> save(List<PendingLocalResult> items);

  /// Sends [item]: null when accepted, the item to keep otherwise.
  Future<(PendingLocalResult?, LocalResendOutcome)> _send(
    AiRepository repo,
    PendingLocalResult item,
  ) async {
    try {
      await repo.submitLocalResult(
        item.analysisId,
        item.messageId,
        item.result,
      );
      return (null, LocalResendOutcome.sent);
    } on DomainError catch (e) {
      // Won't change on retry: kept for its owner to read and decide.
      return (
        item.copyWith(refusedCode: () => e.code),
        LocalResendOutcome.refused,
      );
    } catch (_) {
      return (item, LocalResendOutcome.failed);
    }
  }

  @override
  Future<void> add(PendingLocalResult item) async {
    final items = (await load())
      ..removeWhere((i) => i.messageId == item.messageId);
    await save([...items, item]);
  }

  @override
  Future<void> flush(AiRepository repo, String userId) async {
    if (_flushing) return;
    _flushing = true;
    try {
      final kept = <PendingLocalResult>[];
      for (final item in await load()) {
        if (item.userId != userId || item.refusedCode != null) {
          kept.add(item);
          continue;
        }
        final (keep, _) = await _send(repo, item);
        if (keep != null) kept.add(keep);
      }
      await save(kept);
    } finally {
      _flushing = false;
    }
  }

  @override
  Future<LocalResendOutcome> resend(
    AiRepository repo,
    String userId,
    String messageId,
  ) async {
    final items = await load();
    final i = items.indexWhere((x) => x.messageId == messageId);
    if (i < 0) return LocalResendOutcome.sent;
    if (items[i].userId != userId) return LocalResendOutcome.notOwner;
    final (keep, outcome) = await _send(repo, items[i]);
    // Reload: a flush may have run meanwhile.
    final now = (await load())..removeWhere((x) => x.messageId == messageId);
    await save([...now, ?keep]);
    return outcome;
  }

  @override
  Future<bool> remove(String userId, String messageId) async {
    final items = await load();
    final before = items.length;
    items.removeWhere((x) => x.messageId == messageId && x.userId == userId);
    if (items.length == before) return false;
    await save(items);
    return true;
  }

  @override
  Future<List<PendingLocalResult>> pending() => load();
}

/// The outbox in memory; used by tests and as a fallback.
class MemoryLocalResultOutbox extends _BaseOutbox {
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
  FileLocalResultOutbox(this._file);

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
