import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../errors/error_mapper.dart';

/// One Server-Sent Event. [data] joins multi-line data fields with "\n".
class SseEvent {
  const SseEvent({required this.event, required this.data});

  final String event;
  final String data;

  /// [data] decoded as a JSON object (the backend always sends objects).
  Map<String, dynamic> get json {
    final decoded = jsonDecode(data);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}

/// Parses text/event-stream lines into events. Comment lines (": ping")
/// are skipped; an event is emitted on each blank line, and a final event
/// without its trailing blank line is emitted when the stream closes.
class SseDecoder extends StreamTransformerBase<String, SseEvent> {
  const SseDecoder();

  @override
  Stream<SseEvent> bind(Stream<String> lines) async* {
    var event = '';
    final data = <String>[];
    await for (final rawLine in lines) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          yield SseEvent(
            event: event.isEmpty ? 'message' : event,
            data: data.join('\n'),
          );
        }
        event = '';
        data.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final colon = line.indexOf(':');
      final field = colon < 0 ? line : line.substring(0, colon);
      var value = colon < 0 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          event = value;
        case 'data':
          data.add(value);
      }
    }
    if (data.isNotEmpty) {
      yield SseEvent(
        event: event.isEmpty ? 'message' : event,
        data: data.join('\n'),
      );
    }
  }
}

/// POSTs [body] and returns the response as a stream of events.
///
/// Errors the server reports before streaming (a normal JSON error
/// envelope) are thrown as [AppError]s through [ErrorMapper], like any
/// other request; the auth interceptor still refreshes an expired token.
/// Cancelling [cancelToken] closes the connection, which the backend treats
/// as "stop": it cancels the model call and keeps the partial text.
Stream<SseEvent> postSse(
  Dio dio,
  String path,
  Object body, {
  CancelToken? cancelToken,
}) async* {
  final Response<ResponseBody> response;
  try {
    response = await dio.post<ResponseBody>(
      path,
      data: body,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        // The backend pings every 15 s; anything much longer is a dead
        // connection.
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  } on DioException catch (e) {
    throw ErrorMapper.fromException(await _withDecodedBody(e));
  }

  final lines = response.data!.stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  try {
    yield* lines.transform(const SseDecoder());
  } on DioException catch (e) {
    throw ErrorMapper.fromException(e);
  }
}

/// A streamed error response carries its JSON envelope as a byte stream;
/// read it so [ErrorMapper] can parse it like a normal response.
Future<DioException> _withDecodedBody(DioException e) async {
  final response = e.response;
  final data = response?.data;
  if (response == null || data is! ResponseBody) return e;
  Object? decoded;
  try {
    final text = await utf8.decodeStream(data.stream.cast<List<int>>());
    decoded = jsonDecode(text);
  } catch (_) {
    decoded = null;
  }
  return e.copyWith(
    response: Response<Object?>(
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      headers: response.headers,
      data: decoded,
    ),
  );
}
