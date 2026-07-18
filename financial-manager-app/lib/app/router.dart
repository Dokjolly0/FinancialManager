import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/google_registration_completion_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/transactions/presentation/screens/new_transaction_screen.dart';
import '../features/transactions/presentation/screens/transaction_detail_screen.dart';
import 'app_shell.dart';
import 'placeholder_screen.dart';
import 'session/session_controller.dart';
import 'session/session_status.dart';
import 'splash_screen.dart';

/// Route paths (plan.md section 9.8). Kept as constants so features can
/// navigate (`context.go(AppRoutes.history)`) without repeating string
/// literals.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const registerGoogleCompletion = '/register/google-completion';
  static const forgotPassword = '/forgot-password';

  static const home = '/app/home';
  static const transactionsNew = '/app/transactions/new';
  static const history = '/app/history';
  static const reports = '/app/reports';
  static const account = '/app/account';
  static const accountProfile = '/app/account/profile';
  static const accountSecurity = '/app/account/security';
  static const accountLinkedAccounts = '/app/account/linked-accounts';
  static const accountData = '/app/account/data';

  static String transactionDetail(String id) => '/app/transactions/$id';
  static String transactionEdit(String id) => '/app/transactions/$id/edit';
}

/// Bridges Riverpod state changes to go_router's [Listenable]-based
/// refresh mechanism, so a redirect re-evaluates whenever
/// [sessionControllerProvider] changes.
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _SessionRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final status = ref.read(sessionControllerProvider);
      final path = state.matchedLocation;
      final isAuthRoute =
          path == AppRoutes.splash ||
          path == AppRoutes.login ||
          path == AppRoutes.register ||
          path == AppRoutes.registerGoogleCompletion ||
          path == AppRoutes.forgotPassword;

      switch (status) {
        case SessionStatus.checking:
          return path == AppRoutes.splash ? null : AppRoutes.splash;
        case SessionStatus.unauthenticated:
          return isAuthRoute && path != AppRoutes.splash
              ? null
              : AppRoutes.login;
        case SessionStatus.profileIncomplete:
          return path == AppRoutes.registerGoogleCompletion
              ? null
              : AppRoutes.registerGoogleCompletion;
        case SessionStatus.authenticated:
          return isAuthRoute ? AppRoutes.home : null;
      }
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerGoogleCompletion,
        builder: (_, _) => const GoogleRegistrationCompletionScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionsNew,
        builder: (_, _) => const NewTransactionScreen(),
      ),
      GoRoute(
        path: '/app/transactions/:id',
        builder: (_, state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/app/transactions/:id/edit',
        builder: (_, state) =>
            NewTransactionScreen(editTransactionId: state.pathParameters['id']),
      ),
      ..._placeholderRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (_, _) => const FeaturePlaceholderScreen(
                  routeName: AppRoutes.history,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, _) => const FeaturePlaceholderScreen(
                  routeName: AppRoutes.reports,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (_, _) => const FeaturePlaceholderScreen(
                  routeName: AppRoutes.account,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

const _placeholderPaths = [
  AppRoutes.accountProfile,
  AppRoutes.accountSecurity,
  AppRoutes.accountLinkedAccounts,
  AppRoutes.accountData,
];

final _placeholderRoutes = _placeholderPaths.map(
  (path) => GoRoute(
    path: path,
    builder: (_, _) => FeaturePlaceholderScreen(routeName: path),
  ),
);
