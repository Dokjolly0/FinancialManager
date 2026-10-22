import 'package:financialmanager/core/api/api_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps the /api prefix of the production base URL', () {
    expect(
      resolveApiPath(
        'https://financialmanager.alexviolatto.dev/api/v1',
        '/v1/me/export/abc/download',
      ),
      'https://financialmanager.alexviolatto.dev/api/v1/me/export/abc/download',
    );
  });

  test('works without a prefix, with a port', () {
    expect(
      resolveApiPath('http://10.0.2.2:10003/v1', '/v1/media/1'),
      'http://10.0.2.2:10003/v1/media/1',
    );
  });

  test('ignores trailing slashes and a missing leading slash', () {
    expect(
      resolveApiPath('https://x.dev/api/v1/', 'v1/media/1'),
      'https://x.dev/api/v1/media/1',
    );
  });

  test('a base URL without /v1 is used as the root', () {
    expect(
      resolveApiPath('https://x.dev/api', '/v1/media/1'),
      'https://x.dev/api/v1/media/1',
    );
  });
}
