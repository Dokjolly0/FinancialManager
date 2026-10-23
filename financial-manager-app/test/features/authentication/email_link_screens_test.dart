import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:financialmanager/app/app.dart';
import 'package:financialmanager/app/router.dart';
import 'package:financialmanager/core/errors/app_error.dart';
import 'package:financialmanager/features/authentication/data/providers.dart';
import 'package:financialmanager/features/authentication/domain/models/auth_user.dart';
import 'package:financialmanager/features/authentication/domain/repositories/auth_repository.dart';
import 'package:financialmanager/features/authentication/presentation/screens/login_screen.dart';
import 'package:financialmanager/features/authentication/presentation/screens/reset_password_screen.dart';
import 'package:financialmanager/features/authentication/presentation/screens/verify_email_screen.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

const _expired = DomainError(
  code: 'INVALID_OR_EXPIRED_TOKEN',
  message: 'The link is invalid or has expired.',
);

/// Records the email-link calls; everything else is unused here.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failWith});

  final AppError? failWith;
  final resets = <(String, String)>[];
  final verified = <String>[];

  @override
  Future<AuthUser?> tryRestoreSession() async => null;

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (failWith != null) throw failWith!;
    resets.add((token, newPassword));
  }

  @override
  Future<void> verifyEmail(String token) async {
    if (failWith != null) throw failWith!;
    verified.add(token);
  }

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpAt(
  WidgetTester tester,
  String location,
  _FakeAuthRepository repo,
) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, s) =>
            ResetPasswordScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, s) =>
            VerifyEmailScreen(token: s.uri.queryParameters['token']),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const Text('login')),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const Text('forgot'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillPasswords(WidgetTester tester, String a, String b) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), a);
  await tester.enterText(fields.at(1), b);
  await tester.tap(find.text('Salva la password'));
  await tester.pumpAndSettle();
}

void main() {
  group('ResetPasswordScreen', () {
    testWidgets('sets the new password with the token from the link', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await _pumpAt(tester, '/reset-password?token=abc', repo);

      await _fillPasswords(tester, 'nuovapass1', 'nuovapass1');

      expect(repo.resets, [('abc', 'nuovapass1')]);
      expect(find.textContaining('Password aggiornata'), findsOneWidget);
      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('checks length and confirmation before calling the API', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await _pumpAt(tester, '/reset-password?token=abc', repo);

      await _fillPasswords(tester, 'corta', 'corta');
      expect(find.text('Deve avere almeno 8 caratteri.'), findsOneWidget);

      await _fillPasswords(tester, 'nuovapass1', 'diversa12');
      expect(find.text('Le password non coincidono.'), findsOneWidget);
      expect(repo.resets, isEmpty);
    });

    testWidgets('an expired link offers to request a new one', (tester) async {
      final repo = _FakeAuthRepository(failWith: _expired);
      await _pumpAt(tester, '/reset-password?token=old', repo);

      await _fillPasswords(tester, 'nuovapass1', 'nuovapass1');

      expect(find.text('Il link non è valido o è scaduto.'), findsOneWidget);
      await tester.tap(find.text('Richiedi un nuovo link'));
      await tester.pumpAndSettle();
      expect(find.text('forgot'), findsOneWidget);
    });

    testWidgets('without a token there is no form', (tester) async {
      await _pumpAt(tester, '/reset-password', _FakeAuthRepository());

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Il link non è valido o è scaduto.'), findsOneWidget);
    });
  });

  group('VerifyEmailScreen', () {
    testWidgets('confirms the address as soon as it opens', (tester) async {
      final repo = _FakeAuthRepository();
      await _pumpAt(tester, '/verify-email?token=v1', repo);

      expect(repo.verified, ['v1']);
      expect(find.text('Indirizzo email confermato.'), findsOneWidget);
    });

    testWidgets('reports an expired link', (tester) async {
      await _pumpAt(
        tester,
        '/verify-email?token=old',
        _FakeAuthRepository(failWith: _expired),
      );

      expect(find.text('Il link non è valido o è scaduto.'), findsOneWidget);
      // Signed out: nothing to resend from, only the way back to the app.
      expect(find.text('Invia un nuovo link'), findsNothing);
      expect(find.text("Vai all'app"), findsOneWidget);
    });
  });

  testWidgets('email links stay open without a session; app pages do not', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const FinancialManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );
    final router = container.read(appRouterProvider);

    router.go('/reset-password?token=abc');
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    router.go('/verify-email?token=v1');
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(repo.verified, ['v1']);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
