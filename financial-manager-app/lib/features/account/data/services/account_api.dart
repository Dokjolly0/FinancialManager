import 'package:dio/dio.dart';

/// Thin wrapper over `/v1/me*` and `/v1/auth/password/change` (plan.md
/// sections 14.1, 14.2, 14.3). Returns raw decoded JSON.
class AccountApi {
  AccountApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return response.data!;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>('/me', data: body);
    return response.data!;
  }

  Future<void> deleteMe(String? currentPassword) => _dio.delete<void>(
    '/me',
    data: currentPassword == null
        ? null
        : {'current_password': currentPassword},
  );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _dio.post<void>(
    '/auth/password/change',
    data: {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_new_password': newPassword,
    },
  );

  Future<Map<String, dynamic>> listSessions() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/sessions');
    return response.data!;
  }

  Future<void> revokeSession(String sessionId) =>
      _dio.delete<void>('/me/sessions/$sessionId');

  Future<Map<String, dynamic>> listIdentities() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/identities');
    return response.data!;
  }

  Future<void> linkGoogle({
    required String idToken,
    required String currentPassword,
  }) => _dio.post<void>(
    '/me/identities/google/link',
    data: {'id_token': idToken, 'current_password': currentPassword},
  );

  Future<void> unlinkGoogle() => _dio.delete<void>('/me/identities/google');

  Future<Map<String, dynamic>> requestExport(String format) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/export',
      data: {'format': format},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> getExport(String exportId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/me/export/$exportId',
    );
    return response.data!;
  }
}
