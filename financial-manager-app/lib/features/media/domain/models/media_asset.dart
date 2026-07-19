/// What kind of thing a media asset is attached to (plan.md section 11.8).
/// Every kind in this app is a 1:1 square crop (plan.md section 7.8).
enum MediaKind {
  profile,
  transaction,
  category;

  static MediaKind fromApi(String value) => switch (value) {
    'profile' => MediaKind.profile,
    'transaction' => MediaKind.transaction,
    'category' => MediaKind.category,
    _ => throw ArgumentError('Unknown media kind: $value'),
  };

  String toApi() => switch (this) {
    MediaKind.profile => 'profile',
    MediaKind.transaction => 'transaction',
    MediaKind.category => 'category',
  };
}

/// A stored image (plan.md section 4.1, 11.8, 16). The client never
/// resolves [id] to a raw storage URL itself — display always goes through
/// the authenticated `/v1/media/{id}` endpoint (plan.md section 16.7).
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.kind,
    required this.source,
    this.attribution,
    this.name,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final String id;
  final MediaKind kind;
  final String source;
  final String? attribution;
  final String? name;
  final String mimeType;
  final int width;
  final int height;
  final DateTime createdAt;

  static MediaAsset fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] as String,
      kind: MediaKind.fromApi(json['kind'] as String),
      source: json['source'] as String,
      attribution: json['attribution'] as String?,
      name: json['name'] as String?,
      mimeType: json['mime_type'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// One result from an image-search provider (plan.md section 16.2).
/// [thumbUrl] points directly at the provider's own CDN — no media_asset
/// exists for it yet, and none is created until the user picks it.
class MediaSearchResult {
  const MediaSearchResult({
    required this.externalId,
    required this.thumbUrl,
    required this.attribution,
    required this.width,
    required this.height,
  });

  final String externalId;
  final String thumbUrl;
  final String attribution;
  final int width;
  final int height;

  static MediaSearchResult fromJson(Map<String, dynamic> json) {
    return MediaSearchResult(
      externalId: json['external_id'] as String,
      thumbUrl: json['thumb_url'] as String,
      attribution: json['attribution'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}
