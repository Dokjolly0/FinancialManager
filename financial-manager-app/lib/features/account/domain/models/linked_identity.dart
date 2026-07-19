/// GET /v1/me/identities (plan.md section 7.13 "Account collegati", 14.3).
class LinkedIdentity {
  const LinkedIdentity({
    required this.provider,
    required this.linkedAt,
    this.lastUsedAt,
  });

  final String provider;
  final DateTime linkedAt;
  final DateTime? lastUsedAt;

  factory LinkedIdentity.fromJson(Map<String, dynamic> json) {
    return LinkedIdentity(
      provider: json['provider'] as String,
      linkedAt: DateTime.parse(json['linked_at'] as String),
      lastUsedAt: json['last_used_at'] == null
          ? null
          : DateTime.parse(json['last_used_at'] as String),
    );
  }
}
