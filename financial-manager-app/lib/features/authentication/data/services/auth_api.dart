import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper over the `/v1/auth/*` and `/v1/me`/`/v1/wallet` endpoints
/// (plan.md section 14.1). Returns raw decoded JSON — turning it into
/// domain models is [AuthRepositoryImpl]'s job, not this class's.
class AuthApi {
  AuthApi(this._dio, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Dio _dio;
  final Uuid _uuid;

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username_or_email': usernameOrEmail, 'password': password},
    );
    return response.data!;
  }

  Future<void> logout() => _dio.post<void>('/auth/logout');

  Future<void> logoutAll() => _dio.post<void>('/auth/logout-all');

  Future<void> forgotPassword(String email) =>
      _dio.post<void>('/auth/password/forgot', data: {'email': email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _dio.post<void>(
    '/auth/password/reset',
    data: {'token': token, 'new_password': newPassword},
  );

  Future<void> verifyEmail(String token) =>
      _dio.post<void>('/auth/email/verify', data: {'token': token});

  Future<void> resendVerification() =>
      _dio.post<void>('/auth/email/resend-verification');

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/me');
    return response.data!;
  }
}
