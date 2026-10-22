import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'package:financialmanager/features/ai/data/local/network_status.dart';

/// Deterministic file content of [length] bytes.
Uint8List fakeModelBytes(int length, {int seed = 1, String magic = 'GGUF'}) {
  final out = Uint8List(length);
  var x = seed;
  for (var i = 0; i < length; i++) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    out[i] = x >> 16;
  }
  out.setRange(0, magic.length, ascii.encode(magic));
  return out;
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// Hugging Face and its CDN in one adapter: huggingface.co answers 302 with
/// X-Linked-ETag/X-Linked-Size, the CDN serves [content] with Range,
/// If-Range on [etag], and 416 past the end.
class FakeModelServer implements HttpClientAdapter {
  FakeModelServer(this.content, {this.chunkSize = 1000})
    : linkedSha = sha256Hex(content);

  Uint8List content;
  int chunkSize;
  String etag = '"v1"';

  /// X-Linked-ETag sent by huggingface.co; null leaves it out.
  String? linkedSha;

  /// Forces huggingface.co to answer with this status instead of 302.
  int? hubStatus;

  /// The CDN ignores Range and always sends the whole file.
  bool ignoreRange = false;

  /// Called before each body chunk the CDN sends, with its index.
  void Function(int chunk)? onChunk;

  final requests = <RequestOptions>[];

  List<RequestOptions> get cdnRequests =>
      requests.where((r) => r.uri.host == 'cdn.example').toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.host == 'huggingface.co') {
      if (hubStatus != null) return ResponseBody.fromString('', hubStatus!);
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://cdn.example/files/${options.uri.pathSegments.last}',
          ],
          'x-linked-etag': ?(linkedSha == null ? null : ['"$linkedSha"']),
          'x-linked-size': ['${content.length}'],
        },
      );
    }
    final range = options.headers['Range'] as String?;
    final ifRange = options.headers['If-Range'] as String?;
    var start = 0;
    var status = 200;
    if (range != null && !ignoreRange && (ifRange == null || ifRange == etag)) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= content.length) {
        return ResponseBody.fromString(
          '',
          416,
          headers: {
            'content-range': ['bytes */${content.length}'],
          },
        );
      }
      status = 206;
    }
    final body = content.sublist(start);
    return ResponseBody(
      _chunks(body),
      status,
      headers: {
        'etag': [etag],
        'content-length': ['${body.length}'],
        if (status == 206)
          'content-range': [
            'bytes $start-${content.length - 1}/${content.length}',
          ],
      },
    );
  }

  Stream<Uint8List> _chunks(Uint8List body) async* {
    for (var i = 0, n = 0; i < body.length; i += chunkSize, n++) {
      onChunk?.call(n);
      await Future<void>.delayed(Duration.zero);
      yield body.sublist(
        i,
        i + chunkSize > body.length ? body.length : i + chunkSize,
      );
    }
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeModelServer server) => Dio()..httpClientAdapter = server;

class FakeNetworkStatus implements NetworkStatus {
  FakeNetworkStatus({this.unmetered = true});

  bool unmetered;
  final _changes = StreamController<bool>.broadcast();

  void set(bool value) {
    unmetered = value;
    _changes.add(value);
  }

  @override
  Future<bool> isUnmetered() async => unmetered;

  @override
  Stream<bool> get unmeteredChanges => _changes.stream;
}
