import 'package:dio/dio.dart';

import '../../../../core/auth/google_sign_in_service.dart';
import '../../../../core/auth/session_token_store.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/google_sign_in_outcome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi authApi,
    required SessionTokenStore tokenStore,
    required GoogleSignInService googleSignIn,
  }) : _api = authApi,
       _tokenStore = tokenStore,
       _googleSignIn = googleSignIn;

  final AuthApi _api;
  final SessionTokenStore _tokenStore;
  final GoogleSignInService _googleSignIn;

  AuthUser _userFromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      emailVerified: json['email_verified'] as bool,
    );
  }

  Future<AuthUser> _handleAuthResponse(Map<String, dynamic> json) async {
    await _tokenStore.applyTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
    return _userFromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<AuthUser> register(RegisterParams params) async {
    try {
      final response = await _api.register({
        'first_name': params.firstName,
        'last_name': params.lastName,
        'username': params.username,
        'email': params.email,
        'password': params.password,
        'confirm_password': params.confirmPassword,
        'avatar_background_color': params.avatarBackgroundColor,
        'avatar_text_color': params.avatarTextColor,
        'initial_balance_minor': params.initialBalanceMinor,
        'currency': params.currency,
        'timezone': params.timezone,
        'locale': params.locale,
        'accepted_terms': params.acceptedTerms,
      });
      return await _handleAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<AuthUser> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await _api.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      return await _handleAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    final String idToken;
    try {
      idToken = await _googleSignIn.signIn();
    } on GoogleSignInCancelled {
      return const GoogleSignInCancelledByUser();
    }

    try {
      final response = await _api.googleVerify(idToken);
      if (response['status'] == 'authenticated') {
        return GoogleSignInAuthenticated(await _handleAuthResponse(response));
      }

      return GoogleSignInRegistrationRequired(
        ticket: response['ticket'] as String,
        email: response['email'] as String,
        emailVerified: response['email_verified'] as bool,
        suggestedFirstName: (response['suggested_first_name'] as String?) ?? '',
        suggestedLastName: (response['suggested_last_name'] as String?) ?? '',
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<AuthUser> completeGoogleRegistration(
    GoogleCompletionParams params,
  ) async {
    try {
      final response = await _api.completeGoogleRegistration({
        'ticket': params.ticket,
        'username': params.username,
        'password': params.password,
        'confirm_password': params.confirmPassword,
        'avatar_background_color': params.avatarBackgroundColor,
        'avatar_text_color': params.avatarTextColor,
        'initial_balance_minor': params.initialBalanceMinor,
        'currency': params.currency,
        'timezone': params.timezone,
        'locale': params.locale,
        'accepted_terms': params.acceptedTerms,
      });
      return await _handleAuthResponse(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } on DioException {
      // Best-effort: even if the network call fails, forget the local
      // session — the user asked to log out.
    }
    await _bestEffortGoogleSignOut();
    await _tokenStore.clear();
  }

  @override
  Future<void> logoutAll() async {
    try {
      await _api.logoutAll();
    } on DioException {
      // Same rationale as logout().
    }
    await _bestEffortGoogleSignOut();
    await _tokenStore.clear();
  }

  Future<void> _bestEffortGoogleSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Not linked via Google, or the platform SDK isn't reachable — the
      // local session is cleared regardless.
    }
  }

  @override
  Future<AuthUser?> tryRestoreSession() async {
    if (!await _tokenStore.hasStoredSession()) return null;

    final accessToken = await _tokenStore.refreshAccessToken();
    if (accessToken == null) return null;

    try {
      final response = await _api.getMe();
      return _userFromJson(response);
    } on DioException {
      await _tokenStore.clear();
      return null;
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _api.forgotPassword(email);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _api.resetPassword(token: token, newPassword: newPassword);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> verifyEmail(String token) async {
    try {
      await _api.verifyEmail(token);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<void> resendVerification() async {
    try {
      await _api.resendVerification();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
