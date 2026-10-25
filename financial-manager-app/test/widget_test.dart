import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/app/app.dart';
import 'package:financialmanager/features/authentication/data/providers.dart';
import 'package:financialmanager/features/authentication/domain/models/auth_user.dart';
import 'package:financialmanager/features/authentication/domain/models/google_sign_in_outcome.dart';
import 'package:financialmanager/features/authentication/domain/repositories/auth_repository.dart';
import 'package:financialmanager/features/authentication/presentation/screens/login_screen.dart';

/// Never touches secure storage or the network — the app-shell smoke test
/// only cares that an unauthenticated session redirects to login, not
/// about session-restoration mechanics (that's covered by the auth
/// feature's own tests).
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> tryRestoreSession() async => null;

  @override
  Future<AuthUser> login({
    required String usernameOrEmail,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> register(RegisterParams params) =>
      throw UnimplementedError();

  @override
  Future<GoogleSignInOutcome> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<AuthUser> completeGoogleRegistration(GoogleCompletionParams params) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> logoutAll() => throw UnimplementedError();

  @override
  Future<void> forgotPassword(String email) => throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> verifyEmail(String token) => throw UnimplementedError();

  @override
  Future<void> resendVerification() => throw UnimplementedError();
}

void main() {
  testWidgets('App boots and redirects an unauthenticated session to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const FinancialManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
