/// GET/PATCH /v1/me (plan.md sections 7.13, 14.2).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.emailVerified,
    required this.avatarMode,
    this.avatarMediaId,
    required this.avatarBackgroundColor,
    required this.avatarTextColor,
    required this.locale,
    required this.timezone,
    required this.theme,
    required this.balanceHiddenDefault,
    required this.firstDayOfWeek,
    required this.version,
    required this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final bool emailVerified;
  final String avatarMode;
  final String? avatarMediaId;
  final String avatarBackgroundColor;
  final String avatarTextColor;
  final String locale;
  final String timezone;
  final String theme;
  final bool balanceHiddenDefault;
  final String firstDayOfWeek;
  final int version;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      emailVerified: json['email_verified'] as bool,
      avatarMode: json['avatar_mode'] as String,
      avatarMediaId: json['avatar_media_id'] as String?,
      avatarBackgroundColor: json['avatar_background_color'] as String,
      avatarTextColor: json['avatar_text_color'] as String,
      locale: json['locale'] as String,
      timezone: json['timezone'] as String,
      theme: json['theme'] as String,
      balanceHiddenDefault: json['balance_hidden_default'] as bool,
      firstDayOfWeek: json['first_day_of_week'] as String,
      version: json['version'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
