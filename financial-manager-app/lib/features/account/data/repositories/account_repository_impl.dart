import 'package:dio/dio.dart';

import '../../../../core/auth/access_token_provider.dart';
import '../../../../core/auth/google_sign_in_service.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/account_session.dart';
import '../../domain/models/export_record.dart';
import '../../domain/models/linked_identity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/account_repository.dart';
import '../services/account_api.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(
    this._api,
    this._dio,
    this._tokenProvider,
    this._googleSignIn,
  );

  final AccountApi _api;
  final Dio _dio;
  final AccessTokenProvider _tokenProvider;
  final GoogleSignInService _googleSignIn;

  @override
  Future<UserProfile> getProfile() async {
    try {
      return UserProfile.fromJson(await _api.getMe());
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    try {
      final json = await _api.updateMe({
        'first_name': update.firstName,
        'last_name': update.lastName,
        'timezone': update.timezone,
        'locale': update.locale,
        'theme': update.theme,
        'balance_hidden_default': update.balanceHiddenDefault,
        'first_day_of_week': update.firstDayOfWeek,
        'version': update.expectedVersion,
      });
      return UserProfile.fromJson(json);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<AccountSession>> listSessions() async {
    try {
      final response = await _api.listSessions();
      final raw = response['sessions'] as List<dynamic>? ?? [];
      return raw
          .map((json) => AccountSession.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      await _api.revokeSession(sessionId);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<LinkedIdentity>> listIdentities() async {
    try {
      final response = await _api.listIdentities();
      final raw = response['identities'] as List<dynamic>? ?? [];
      return raw
          .map((json) => LinkedIdentity.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> linkGoogle(String currentPassword) async {
    final idToken = await _googleSignIn.signIn();
    try {
      await _api.linkGoogle(idToken: idToken, currentPassword: currentPassword);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> unlinkGoogle() async {
    try {
      await _api.unlinkGoogle();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Best-effort: the backend link is already gone either way.
    }
  }

  @override
  Future<ExportRecord> requestExport(String format) async {
    try {
      return ExportRecord.fromJson(await _api.requestExport(format));
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<ExportRecord> getExport(String exportId) async {
    try {
      return ExportRecord.fromJson(await _api.getExport(exportId));
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    try {
      await _api.deleteMe(currentPassword);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  String resolveDownloadUrl(String relativeUrl) {
    // relativeUrl already starts with "/v1/..." (it's the backend's own
    // route path), but Dio's baseUrl also ends in "/v1" — concatenating
    // them directly would duplicate that segment, so this resolves
    // against the origin (scheme://host:port) instead.
    final origin = Uri.parse(_dio.options.baseUrl);
    return Uri(
      scheme: origin.scheme,
      host: origin.host,
      port: origin.port,
      path: relativeUrl,
    ).toString();
  }

  @override
  Map<String, String> authHeaders() {
    final token = _tokenProvider.currentAccessToken;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }
}
