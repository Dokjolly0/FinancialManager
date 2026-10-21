import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'model_files.dart';
import 'network_status.dart';

/// Failure codes of a model download, localized by the app.
abstract final class ModelDownloadErrors {
  static const network = 'AI_LOCAL_DOWNLOAD_NETWORK';

  /// 401/403: a gated repository (license to accept, token to set).
  static const gated = 'AI_LOCAL_DOWNLOAD_GATED';
  static const notFound = 'AI_LOCAL_DOWNLOAD_NOT_FOUND';
  static const http = 'AI_LOCAL_DOWNLOAD_HTTP';
  static const noSpace = 'AI_LOCAL_DOWNLOAD_NO_SPACE';

  /// Size or SHA-256 differ from what was expected.
  static const checksum = 'AI_LOCAL_DOWNLOAD_CHECKSUM';
  static const insecureUrl = 'AI_LOCAL_DOWNLOAD_INSECURE_URL';
}

class ModelDownloadException implements Exception {
  const ModelDownloadException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() =>
      'ModelDownloadException($code${message == null ? '' : ': $message'})';
}

enum ModelDownloadPauseReason { user, waitingForWifi }

/// The download stopped before the end; the partial file is kept and the
/// next [ModelDownloader.download] resumes it.
class ModelDownloadPaused implements Exception {
  const ModelDownloadPaused(this.reason);

  final ModelDownloadPauseReason reason;

  @override
  String toString() => 'ModelDownloadPaused(${reason.name})';
}

enum ModelDownloadStage { downloading, verifying }

typedef ModelDownloadProgress =
    void Function(ModelDownloadStage stage, int receivedBytes, int? totalBytes);

class ModelDownloadRequest {
  const ModelDownloadRequest({
    required this.url,
    required this.target,
    this.sha256,
    this.sizeBytes,
  });

  final String url;

  /// Where the verified file ends up; `<target>.part` while downloading.
  final File target;

  /// Expected checksum and size; null for a URL import without them.
  final String? sha256;
  final int? sizeBytes;
}

class ModelDownloadResult {
  const ModelDownloadResult({
    required this.sha256,
    required this.sizeBytes,
    required this.resumedFrom,
  });

  final String sha256;
  final int sizeBytes;

  /// Bytes already on disk when this download started.
  final int resumedFrom;
}

/// Downloads a model file, resumably (plan.md section 33).
///
/// - The file grows in `<target>.part`. A later call resumes with `Range`,
///   and with `If-Range` on the server's validator so a changed file
///   restarts from zero instead of being spliced (206 continues, 200
///   restarts, 416 on a complete part goes straight to verification).
/// - Redirects are followed here, not by Dio, so `Range` reaches the CDN
///   that Hugging Face redirects to. Hugging Face's first response carries
///   `X-Linked-ETag` (the file's SHA-256) and `X-Linked-Size`: a mismatch
///   with the expected values fails before downloading gigabytes.
/// - The Hugging Face token is sent only to huggingface.co, never to the
///   CDN or any other host.
/// - With [wifiOnly], the download doesn't start off Wi-Fi and pauses when
///   Wi-Fi drops ([ModelDownloadPaused], partial file kept).
/// - Free space must cover the rest of the file plus [spaceMargin].
/// - The finished file is checked for size and SHA-256 (in an isolate)
///   before it is renamed into place; a mismatch deletes it.
class ModelDownloader {
  ModelDownloader({
    required Dio dio,
    required NetworkStatus network,
    required Future<int?> Function(Directory dir) freeBytes,
    Future<String> Function(String path) hasher = sha256OfFile,
    Future<String?> Function()? huggingFaceToken,
    this.progressInterval = const Duration(milliseconds: 250),
  }) : _dio = dio,
       _network = network,
       _freeBytes = freeBytes,
       _hasher = hasher,
       _token = huggingFaceToken;

  final Dio _dio;
  final NetworkStatus _network;
  final Future<int?> Function(Directory dir) _freeBytes;
  final Future<String> Function(String path) _hasher;
  final Future<String?> Function()? _token;
  final Duration progressInterval;

  static const spaceMargin = 512 * 1024 * 1024;
  static const _maxRedirects = 8;

  Future<ModelDownloadResult> download(
    ModelDownloadRequest request, {
    bool wifiOnly = true,
    CancelToken? cancelToken,
    ModelDownloadProgress? onProgress,
  }) async {
    if (Uri.tryParse(request.url)?.scheme != 'https') {
      throw const ModelDownloadException(ModelDownloadErrors.insecureUrl);
    }
    final part = File('${request.target.path}.part');
    final meta = File('${request.target.path}.part.json');
    await request.target.parent.create(recursive: true);

    if (wifiOnly && !await _network.isUnmetered()) {
      throw const ModelDownloadPaused(ModelDownloadPauseReason.waitingForWifi);
    }

    final size = request.sizeBytes;
    var offset = await part.exists() ? await part.length() : 0;
    if (size != null && offset > size) {
      await _discard(part, meta);
      offset = 0;
    }
    final resumedFrom = offset;

    if (size == null || offset < size) {
      final free = await _freeBytes(request.target.parent);
      if (free != null && size != null && free < size - offset + spaceMargin) {
        throw ModelDownloadException(
          ModelDownloadErrors.noSpace,
          'need ${size - offset + spaceMargin} bytes, $free free',
        );
      }
      await _transfer(
        request,
        part,
        meta,
        wifiOnly: wifiOnly,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    }

    final length = await part.length();
    onProgress?.call(ModelDownloadStage.verifying, length, size ?? length);
    if (size != null && length != size) {
      await _discard(part, meta);
      throw ModelDownloadException(
        ModelDownloadErrors.checksum,
        'size $length, expected $size',
      );
    }
    final hash = await _hasher(part.path);
    if (request.sha256 != null && hash != request.sha256!.toLowerCase()) {
      await _discard(part, meta);
      throw ModelDownloadException(
        ModelDownloadErrors.checksum,
        'sha256 $hash, expected ${request.sha256}',
      );
    }
    if (await request.target.exists()) await request.target.delete();
    await part.rename(request.target.path);
    if (await meta.exists()) await meta.delete();
    return ModelDownloadResult(
      sha256: hash,
      sizeBytes: length,
      resumedFrom: resumedFrom,
    );
  }

  /// Fetches the rest of the file into [part], pausing on cancel or on
  /// losing Wi-Fi.
  Future<void> _transfer(
    ModelDownloadRequest request,
    File part,
    File meta, {
    required bool wifiOnly,
    required CancelToken? cancelToken,
    required ModelDownloadProgress? onProgress,
  }) async {
    final inner = CancelToken();
    var lostWifi = false;
    final wifi = wifiOnly
        ? _network.unmeteredChanges.listen((unmetered) {
            if (!unmetered) {
              lostWifi = true;
              inner.cancel('wifi lost');
            }
          })
        : null;
    unawaited(cancelToken?.whenCancel.then((_) => inner.cancel('paused')));
    try {
      // One restart from zero is allowed when the server's answer doesn't
      // fit the partial file (bad Content-Range, 416 on an incomplete part).
      for (var attempt = 0; ; attempt++) {
        try {
          await _fetch(request, part, meta, inner, onProgress);
          return;
        } on _RestartFromZero {
          if (attempt > 0) {
            throw const ModelDownloadException(
              ModelDownloadErrors.http,
              'the server does not resume this file consistently',
            );
          }
          await _discard(part, meta);
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw ModelDownloadPaused(
          lostWifi
              ? ModelDownloadPauseReason.waitingForWifi
              : ModelDownloadPauseReason.user,
        );
      }
      throw ModelDownloadException(ModelDownloadErrors.network, e.message);
    } on SocketException catch (e) {
      throw ModelDownloadException(ModelDownloadErrors.network, e.message);
    } finally {
      await wifi?.cancel();
    }
  }

  Future<void> _fetch(
    ModelDownloadRequest request,
    File part,
    File meta,
    CancelToken cancel,
    ModelDownloadProgress? onProgress,
  ) async {
    var offset = await part.exists() ? await part.length() : 0;
    final validator = offset > 0
        ? await _readValidator(meta, request.url)
        : null;
    final token = await _token?.call();
    var uri = Uri.parse(request.url);

    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            if (offset > 0) 'Range': 'bytes=$offset-',
            if (offset > 0 && validator != null) 'If-Range': validator,
            if (token != null &&
                token.isNotEmpty &&
                uri.host == 'huggingface.co')
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      final headers = response.headers;
      _checkLinked(request, headers);

      final location = headers.value('location');
      if (status >= 300 && status < 400 && location != null) {
        await _drain(response);
        uri = uri.resolve(location);
        continue;
      }
      switch (status) {
        case 401 || 403:
          await _drain(response);
          throw ModelDownloadException(ModelDownloadErrors.gated, '$status');
        case 404:
          await _drain(response);
          throw const ModelDownloadException(ModelDownloadErrors.notFound);
        case 416:
          await _drain(response);
          // Nothing left to send: the part is complete when it has the
          // file's size (expected, or "bytes */<size>" from the server).
          final total =
              request.sizeBytes ??
              int.tryParse(
                RegExp(r'/(\d+)$')
                        .firstMatch(headers.value('content-range') ?? '')
                        ?.group(1) ??
                    '',
              );
          if (total != null && offset == total) return;
          throw const _RestartFromZero();
        case 200:
          offset = 0;
        case 206:
          final start = _contentRangeStart(headers.value('content-range'));
          if (start != offset) {
            await _drain(response);
            throw const _RestartFromZero();
          }
        default:
          await _drain(response);
          throw ModelDownloadException(ModelDownloadErrors.http, '$status');
      }

      final newValidator =
          headers.value('etag') ?? headers.value('last-modified');
      await _writeValidator(meta, request.url, newValidator);
      final length = int.tryParse(headers.value('content-length') ?? '');
      final total =
          request.sizeBytes ?? (length == null ? null : offset + length);
      await _write(response.data!, part, offset, total, onProgress);
      return;
    }
    throw const ModelDownloadException(
      ModelDownloadErrors.http,
      'too many redirects',
    );
  }

  /// Hugging Face states the file's SHA-256 and size before redirecting.
  void _checkLinked(ModelDownloadRequest request, Headers headers) {
    final etag = headers
        .value('x-linked-etag')
        ?.replaceAll('"', '')
        .toLowerCase();
    final expected = request.sha256?.toLowerCase();
    if (expected != null &&
        etag != null &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(etag) &&
        etag != expected) {
      throw ModelDownloadException(
        ModelDownloadErrors.checksum,
        'server file is $etag, expected $expected',
      );
    }
    final size = int.tryParse(headers.value('x-linked-size') ?? '');
    if (request.sizeBytes != null &&
        size != null &&
        size != request.sizeBytes) {
      throw ModelDownloadException(
        ModelDownloadErrors.checksum,
        'server file is $size bytes, expected ${request.sizeBytes}',
      );
    }
  }

  Future<void> _write(
    ResponseBody body,
    File part,
    int offset,
    int? total,
    ModelDownloadProgress? onProgress,
  ) async {
    final sink = part.openWrite(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    var received = offset;
    final sinceProgress = Stopwatch()..start();
    onProgress?.call(ModelDownloadStage.downloading, received, total);
    try {
      await for (final Uint8List chunk in body.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (sinceProgress.elapsed >= progressInterval) {
          sinceProgress.reset();
          onProgress?.call(ModelDownloadStage.downloading, received, total);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    onProgress?.call(ModelDownloadStage.downloading, received, total);
  }

  static int? _contentRangeStart(String? value) {
    final m = RegExp(r'^bytes (\d+)-').firstMatch(value ?? '');
    return m == null ? null : int.parse(m.group(1)!);
  }

  static Future<void> _drain(Response<ResponseBody> response) async {
    try {
      await response.data?.stream.drain<void>();
    } catch (_) {}
  }

  Future<String?> _readValidator(File meta, String url) async {
    try {
      final json =
          jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      return json['url'] == url ? json['validator'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeValidator(File meta, String url, String? validator) =>
      meta.writeAsString(
        jsonEncode({'url': url, 'validator': validator}),
        flush: true,
      );

  static Future<void> _discard(File part, File meta) async {
    if (await part.exists()) await part.delete();
    if (await meta.exists()) await meta.delete();
  }
}

class _RestartFromZero implements Exception {
  const _RestartFromZero();
}
