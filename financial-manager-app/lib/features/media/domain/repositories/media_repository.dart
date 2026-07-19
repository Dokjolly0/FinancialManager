import 'dart:typed_data';

import '../models/media_asset.dart';

/// Domain-facing media operations (plan.md section 14.8). The interactive
/// crop step (plan.md section 7.8) happens client-side via image_cropper
/// before [uploadFile] is ever called, so the uploaded bytes are already a
/// square — the backend still independently re-crops/re-encodes rather than
/// trusting that (plan.md section 16.3/16.5), but the client never needs to
/// compute or send crop coordinates itself.
abstract class MediaRepository {
  Future<List<MediaAsset>> list({
    required MediaKind kind,
    bool sortRecent = false,
    int limit = 40,
    String? query,
  });

  Future<List<MediaSearchResult>> search({
    required String query,
    int page = 1,
    int limit = 20,
  });

  Future<MediaAsset> uploadFile({
    required MediaKind kind,
    required Uint8List bytes,
    required String filename,
  });

  Future<MediaAsset> selectFromSearch({
    required MediaKind kind,
    required String provider,
    required String externalId,
  });

  Future<void> delete(String id);

  Future<MediaAsset> rename({required String id, required String name});

  /// The authenticated URL to fetch an asset's raw bytes from — used to
  /// build a `NetworkImage(url, headers: ...)` (plan.md section 16.7).
  String contentUrl(String id);

  /// The `Authorization` header value to pass alongside [contentUrl].
  Map<String, String> authHeaders();
}
