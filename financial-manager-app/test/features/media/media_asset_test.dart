import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/media/domain/models/media_asset.dart';

void main() {
  test('MediaAsset.fromJson parses the backend shape', () {
    final asset = MediaAsset.fromJson({
      'id': 'abc',
      'kind': 'transaction',
      'source': 'upload',
      'mime_type': 'image/jpeg',
      'width': 512,
      'height': 512,
      'created_at': '2026-07-18T12:00:00Z',
    });
    expect(asset.id, 'abc');
    expect(asset.kind, MediaKind.transaction);
    expect(asset.source, 'upload');
    expect(asset.attribution, isNull);
  });

  test('MediaSearchResult.fromJson parses the backend shape', () {
    final result = MediaSearchResult.fromJson({
      'external_id': 'xyz',
      'thumb_url': 'https://images.unsplash.com/thumb',
      'attribution': 'Photo by Jane Doe on Unsplash',
      'width': 4000,
      'height': 3000,
    });
    expect(result.externalId, 'xyz');
    expect(result.thumbUrl, 'https://images.unsplash.com/thumb');
    expect(result.attribution, 'Photo by Jane Doe on Unsplash');
  });

  test('MediaKind round-trips through the API string', () {
    for (final kind in MediaKind.values) {
      expect(MediaKind.fromApi(kind.toApi()), kind);
    }
  });
}
