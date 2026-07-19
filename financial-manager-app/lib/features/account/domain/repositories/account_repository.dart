import '../models/account_session.dart';
import '../models/export_record.dart';
import '../models/linked_identity.dart';
import '../models/user_profile.dart';

/// Fields PATCH /v1/me accepts together — the backend replaces the whole
/// profile+preferences record, not individual fields (plan.md section
/// 14.2), so callers always send the full set alongside the version they
/// read.
class ProfileUpdate {
  const ProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.timezone,
    required this.locale,
    required this.theme,
    required this.balanceHiddenDefault,
    required this.firstDayOfWeek,
    required this.expectedVersion,
  });

  final String firstName;
  final String lastName;
  final String timezone;
  final String locale;
  final String theme;
  final bool balanceHiddenDefault;
  final String firstDayOfWeek;
  final int expectedVersion;
}

abstract class AccountRepository {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(ProfileUpdate update);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<List<AccountSession>> listSessions();
  Future<void> revokeSession(String sessionId);

  Future<List<LinkedIdentity>> listIdentities();

  /// Runs the native Google sign-in flow and links the resulting account
  /// (plan.md section 14.3: "richiedere autenticazione recente" — proven
  /// here by [currentPassword]).
  Future<void> linkGoogle(String currentPassword);
  Future<void> unlinkGoogle();

  Future<ExportRecord> requestExport(String format);
  Future<ExportRecord> getExport(String exportId);

  /// Deletes the account (plan.md section 20.3). [currentPassword] is
  /// required only for accounts that have a local password.
  Future<void> deleteAccount({String? currentPassword});

  /// Resolves an [ExportRecord.downloadUrl] (a relative API path) to an
  /// absolute URL, mirroring MediaRepository.contentUrl.
  String resolveDownloadUrl(String relativeUrl);

  /// Authorization header to attach when fetching [resolveDownloadUrl]'s
  /// result directly (e.g. via a plain HTTP client, outside Dio).
  Map<String, String> authHeaders();
}
