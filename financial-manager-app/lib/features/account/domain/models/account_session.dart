/// GET /v1/me/sessions (plan.md section 7.13 "Sessioni attive").
class AccountSession {
  const AccountSession({
    required this.id,
    this.deviceName,
    this.platform,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    required this.isCurrent,
  });

  final String id;
  final String? deviceName;
  final String? platform;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final bool isCurrent;

  factory AccountSession.fromJson(Map<String, dynamic> json) {
    return AccountSession(
      id: json['id'] as String,
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isCurrent: json['is_current'] as bool,
    );
  }
}
