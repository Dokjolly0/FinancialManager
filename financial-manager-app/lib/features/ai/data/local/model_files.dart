import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../domain/models/local_model.dart';

/// SHA-256 of a file, lowercase hex. Runs in a background isolate and reads
/// in 4 MB chunks: model files are gigabytes (~150 MB/s on an S26 Ultra).
Future<String> sha256OfFile(String path) => Isolate.run(() {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  final raf = File(path).openSync();
  try {
    while (true) {
      final chunk = raf.readSync(4 << 20);
      if (chunk.isEmpty) break;
      input.add(chunk);
    }
  } finally {
    raf.closeSync();
  }
  input.close();
  return sink.value.toString();
});

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// The engine that reads a model file, from its first bytes: GGUF files
/// start with "GGUF", LiteRT-LM bundles with "LITERTLM". Null otherwise.
LocalEngineKind? engineFromHeader(List<int> header) {
  String ascii(int n) =>
      header.length < n ? '' : String.fromCharCodes(header.sublist(0, n));
  if (ascii(4) == 'GGUF') return LocalEngineKind.llamaCpp;
  if (ascii(8) == 'LITERTLM') return LocalEngineKind.litertLm;
  return null;
}

Future<LocalEngineKind?> engineOfFile(File file) async {
  final raf = await file.open();
  try {
    return engineFromHeader(await raf.read(8));
  } finally {
    await raf.close();
  }
}
