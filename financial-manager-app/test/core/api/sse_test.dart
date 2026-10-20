import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/api/sse.dart';
import 'package:financialmanager/core/errors/app_error.dart';

/// Decodes [chunks] (raw bytes, split anywhere) the way postSse does.
Future<List<SseEvent>> _decode(List<List<int>> chunks) {
  return Stream<List<int>>.fromIterable(chunks)
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .transform(const SseDecoder())
      .toList();
}

/// Answers every request with a fixed status and body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(
    this.status,
    this.chunks, {
    this.contentType = 'text/event-stream',
  });

  final int status;
  final List<List<int>> chunks;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable(chunks.map(Uint8List.fromList)),
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SseDecoder', () {
    test('parses events, joins multi-line data and skips comments', () async {
      final events = await _decode([
        utf8.encode(
          ': ping\n\nevent: meta\ndata: {"a":1}\n\nevent: delta\ndata: line1\ndata: line2\n\n',
        ),
      ]);
      expect(events.map((e) => e.event), ['meta', 'delta']);
      expect(events[0].json, {'a': 1});
      expect(events[1].data, 'line1\nline2');
    });

    test('survives chunks that split lines and multi-byte characters', () async {
      final bytes = utf8.encode(
        'event: delta\r\ndata: {"text":"perché €"}\r\n\r\nevent: done\r\ndata: {}\r\n\r\n',
      );
      // Split inside "é" (2 bytes) and inside "€" (3 bytes) and mid-line.
      final splitAt = [5, 32, 33, 37, 38, 39];
      final chunks = <List<int>>[];
      var start = 0;
      for (final s in splitAt) {
        chunks.add(bytes.sublist(start, s));
        start = s;
      }
      chunks.add(bytes.sublist(start));

      final events = await _decode(chunks);
      expect(events.map((e) => e.event), ['delta', 'done']);
      expect(events[0].json['text'], 'perché €');
    });

    test('emits a final event without the trailing blank line', () async {
      final events = await _decode([
        utf8.encode('event: done\ndata: {"status":"COMPLETED"}'),
      ]);
      expect(events.single.json['status'], 'COMPLETED');
    });

    test('defaults the event name to message', () async {
      final events = await _decode([utf8.encode('data: x\n\n')]);
      expect(events.single.event, 'message');
    });
  });

  group('postSse', () {
    test('streams the events of a 200 response', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeAdapter(200, [
          utf8.encode('event: delta\ndata: {"text":"ciao"}\n\n'),
        ]);
      final events = await postSse(dio, '/ai/analyses', {}).toList();
      expect(events.single.json['text'], 'ciao');
    });

    test('turns a JSON error envelope into a DomainError', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))
        ..httpClientAdapter = _FakeAdapter(409, [
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'AI_DATA_CHANGED',
                'message': 'Your data changed.',
              },
            }),
          ),
        ], contentType: 'application/json');

      await expectLater(
        postSse(dio, '/ai/analyses', {}).toList(),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'AI_DATA_CHANGED'),
        ),
      );
    });
  });
}
