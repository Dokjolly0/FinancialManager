import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/model_downloader.dart';

import 'fakes/fake_model_server.dart';

const _url =
    'https://huggingface.co/org/repo/resolve/0123456789abcdef0123456789abcdef01234567/model.gguf';

void main() {
  late Directory dir;
  late FakeModelServer server;
  late FakeNetworkStatus network;
  late File target;
  int? free;
  String? token;

  final content = fakeModelBytes(10000);
  final sha = sha256Hex(content);

  ModelDownloader downloader() => ModelDownloader(
    dio: fakeDio(server),
    network: network,
    freeBytes: (_) async => free,
    huggingFaceToken: () async => token,
    progressInterval: Duration.zero,
  );

  ModelDownloadRequest request({
    String url = _url,
    String? sha256,
    int? size,
  }) => ModelDownloadRequest(
    url: url,
    target: target,
    sha256: sha256 ?? sha,
    sizeBytes: size ?? content.length,
  );

  File part() => File('${target.path}.part');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fm_dl_');
    target = File('${dir.path}/m/model.gguf');
    server = FakeModelServer(content);
    network = FakeNetworkStatus();
    free = null;
    token = null;
  });

  tearDown(() => dir.delete(recursive: true));

  test('downloads through the redirect, verifies and installs', () async {
    token = 'hf_secret';
    final stages = <ModelDownloadStage>{};
    final r = await downloader().download(
      request(),
      onProgress: (s, _, _) => stages.add(s),
    );

    expect(r.sha256, sha);
    expect(r.resumedFrom, 0);
    expect(await target.readAsBytes(), content);
    expect(await part().exists(), isFalse);
    expect(stages, {
      ModelDownloadStage.downloading,
      ModelDownloadStage.verifying,
    });
    // The token goes to huggingface.co only, never to the CDN.
    expect(server.requests.first.headers['Authorization'], 'Bearer hf_secret');
    expect(
      server.cdnRequests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(server.requests.every((r) => r.followRedirects == false), isTrue);
  });

  test('a paused download resumes with Range and If-Range', () async {
    final token = CancelToken();
    server.onChunk = (n) {
      if (n == 3) token.cancel();
    };
    await expectLater(
      downloader().download(request(), cancelToken: token),
      throwsA(
        isA<ModelDownloadPaused>().having(
          (p) => p.reason,
          'reason',
          ModelDownloadPauseReason.user,
        ),
      ),
    );
    final kept = await part().length();
    expect(kept, greaterThan(0));
    expect(kept, lessThan(content.length));

    server.onChunk = null;
    final r = await downloader().download(request());

    final resume = server.cdnRequests.last;
    expect(resume.headers['Range'], 'bytes=$kept-');
    expect(resume.headers['If-Range'], '"v1"');
    expect(r.resumedFrom, kept);
    expect(await target.readAsBytes(), content);
  });

  test('a changed file on the server restarts from zero', () async {
    final token = CancelToken();
    server.onChunk = (n) {
      if (n == 2) token.cancel();
    };
    await expectLater(
      downloader().download(request(), cancelToken: token),
      throwsA(isA<ModelDownloadPaused>()),
    );

    // New revision behind the same URL: If-Range no longer matches, the
    // CDN sends the whole file with 200.
    final changed = fakeModelBytes(content.length, seed: 2);
    server
      ..onChunk = null
      ..content = changed
      ..etag = '"v2"'
      ..linkedSha = null;
    final r = await downloader().download(request(sha256: sha256Hex(changed)));

    expect(r.sha256, sha256Hex(changed));
    expect(await target.readAsBytes(), changed);
  });

  test('a server that ignores Range still yields the right file', () async {
    final token = CancelToken();
    server.onChunk = (n) {
      if (n == 4) token.cancel();
    };
    await expectLater(
      downloader().download(request(), cancelToken: token),
      throwsA(isA<ModelDownloadPaused>()),
    );
    server
      ..onChunk = null
      ..ignoreRange = true;
    await downloader().download(request());
    expect(await target.readAsBytes(), content);
  });

  test('416 on a complete part goes straight to verification', () async {
    await target.parent.create(recursive: true);
    await part().writeAsBytes(content);
    // A URL import without a known size: the server's 416 says the part
    // already holds the whole file.
    final r = await downloader().download(
      ModelDownloadRequest(url: _url, target: target),
    );
    expect(
      server.cdnRequests.single.headers['Range'],
      'bytes=${content.length}-',
    );
    expect(r.sha256, sha);
    expect(await target.exists(), isTrue);
  });

  test('a wrong checksum deletes the file', () async {
    server.linkedSha = null;
    await expectLater(
      downloader().download(request(sha256: 'a' * 64)),
      throwsA(
        isA<ModelDownloadException>().having(
          (e) => e.code,
          'code',
          ModelDownloadErrors.checksum,
        ),
      ),
    );
    expect(await part().exists(), isFalse);
    expect(await target.exists(), isFalse);
  });

  test(
    'X-Linked-ETag different from the catalog fails before downloading',
    () async {
      server.linkedSha = 'b' * 64;
      await expectLater(
        downloader().download(request()),
        throwsA(
          isA<ModelDownloadException>().having(
            (e) => e.code,
            'code',
            ModelDownloadErrors.checksum,
          ),
        ),
      );
      expect(server.cdnRequests, isEmpty);
    },
  );

  test('a gated or missing repository is reported as such', () async {
    for (final (status, code) in [
      (401, ModelDownloadErrors.gated),
      (403, ModelDownloadErrors.gated),
      (404, ModelDownloadErrors.notFound),
      (500, ModelDownloadErrors.http),
    ]) {
      server.hubStatus = status;
      await expectLater(
        downloader().download(request()),
        throwsA(
          isA<ModelDownloadException>().having((e) => e.code, 'code', code),
        ),
      );
    }
  });

  test('not enough free space fails before downloading', () async {
    free = content.length + ModelDownloader.spaceMargin - 1;
    await expectLater(
      downloader().download(request()),
      throwsA(
        isA<ModelDownloadException>().having(
          (e) => e.code,
          'code',
          ModelDownloadErrors.noSpace,
        ),
      ),
    );
    expect(server.requests, isEmpty);

    free = content.length + ModelDownloader.spaceMargin;
    await downloader().download(request());
    expect(await target.exists(), isTrue);
  });

  test('Wi-Fi only: waits off Wi-Fi and pauses when Wi-Fi drops', () async {
    network.unmetered = false;
    await expectLater(
      downloader().download(request()),
      throwsA(
        isA<ModelDownloadPaused>().having(
          (p) => p.reason,
          'reason',
          ModelDownloadPauseReason.waitingForWifi,
        ),
      ),
    );
    expect(server.requests, isEmpty);

    // Allowed on mobile data when the rule is off.
    await downloader().download(request(), wifiOnly: false);
    expect(await target.exists(), isTrue);
    await target.delete();

    network.unmetered = true;
    server.onChunk = (n) {
      if (n == 3) network.set(false);
    };
    await expectLater(
      downloader().download(request()),
      throwsA(
        isA<ModelDownloadPaused>().having(
          (p) => p.reason,
          'reason',
          ModelDownloadPauseReason.waitingForWifi,
        ),
      ),
    );
    expect(await part().length(), greaterThan(0));
  });

  test('only https URLs are downloaded', () async {
    await expectLater(
      downloader().download(request(url: 'http://example.com/model.gguf')),
      throwsA(
        isA<ModelDownloadException>().having(
          (e) => e.code,
          'code',
          ModelDownloadErrors.insecureUrl,
        ),
      ),
    );
    expect(server.requests, isEmpty);
  });
}
