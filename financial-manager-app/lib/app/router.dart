import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/screens/account_data_screen.dart';
import '../features/account/presentation/screens/account_linked_accounts_screen.dart';
import '../features/account/presentation/screens/account_preferences_screen.dart';
import '../features/account/presentation/screens/account_profile_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';
import '../features/account/presentation/screens/account_security_screen.dart';
import '../features/ai/presentation/screens/ai_analysis_screen.dart';
import '../features/ai/presentation/screens/ai_analysis_setup_screen.dart';
import '../features/ai/presentation/screens/ai_assistant_screen.dart';
import '../features/ai/presentation/screens/ai_history_screen.dart';
import '../features/ai/presentation/screens/ai_prompt_preview_screen.dart';
import '../features/ai/presentation/screens/ai_personal_context_screen.dart';
import '../features/ai/presentation/screens/ai_provider_settings_screen.dart';
import '../features/ai/presentation/screens/ai_wallet_purposes_screen.dart';
import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/google_registration_completion_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/reports/presentation/screens/report_screen.dart';
import '../features/transactions/presentation/screens/new_transaction_screen.dart';
import '../features/transactions/presentation/screens/payment_groups_screen.dart';
import '../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../features/wallets/presentation/screens/wallet_form_screen.dart';
import '../features/wallets/presentation/screens/wallets_screen.dart';
import 'app_shell.dart';
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
  static const paymentGroups = '/app/transactions/payment-groups';
  static const history = '/app/history';
  static const reports = '/app/reports';
  static const account = '/app/account';
  static const accountProfile = '/app/account/profile';
  static const accountSecurity = '/app/account/security';
  static const accountLinkedAccounts = '/app/account/linked-accounts';
  static const accountPreferences = '/app/account/preferences';
  static const accountData = '/app/account/data';
  static const wallets = '/app/account/wallets';
  static const walletsNew = '/app/account/wallets/new';

  // AI analysis settings (plan.md section 32.7).
  static const aiAssistant = '/app/account/ai';
  static const aiProvider = '/app/account/ai/provider';
  static const aiContext = '/app/account/ai/context';
  static const aiWalletPurposes = '/app/account/ai/wallet-purposes';

  // AI analysis flow: setup → preview → run, plus the history.
  static const aiNew = '/app/ai/new';
  static const aiPreview = '/app/ai/preview';
  static const aiRun = '/app/ai/run';
  static const aiHistory = '/app/ai/analyses';
  static String aiAnalysis(String id) => '/app/ai/analyses/$id';

  static String transactionDetail(String id) => '/app/transactions/$id';
  static String transactionEdit(String id) => '/app/transactions/$id/edit';

  /// Opens the new-transaction form pre-linked to [sourceId] — "aggiungi
  /// pagamento collegato" (plan.md linked-transactions feature).
  static String transactionsNewLinkedTo(String sourceId) =>
      '$transactionsNew?linkTo=$sourceId';

  static String walletEdit(String id) => '/app/account/wallets/$id/edit';
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
        builder: (_, state) => NewTransactionScreen(
          linkToTransactionId: state.uri.queryParameters['linkTo'],
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentGroups,
        builder: (_, _) => const PaymentGroupsScreen(),
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
      GoRoute(
        path: AppRoutes.accountProfile,
        builder: (_, _) => const AccountProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountSecurity,
        builder: (_, _) => const AccountSecurityScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountLinkedAccounts,
        builder: (_, _) => const AccountLinkedAccountsScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountPreferences,
        builder: (_, _) => const AccountPreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountData,
        builder: (_, _) => const AccountDataScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallets,
        builder: (_, _) => const WalletsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (_, _) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiProvider,
        builder: (_, _) => const AiProviderSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiContext,
        builder: (_, _) => const AiPersonalContextScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiWalletPurposes,
        builder: (_, _) => const AiWalletPurposesScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiNew,
        builder: (_, _) => const AiAnalysisSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiPreview,
        builder: (_, _) => const AiPromptPreviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiRun,
        builder: (_, _) => const AiAnalysisScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiHistory,
        builder: (_, _) => const AiHistoryScreen(),
      ),
      GoRoute(
        path: '/app/ai/analyses/:id',
        builder: (_, state) =>
            AiAnalysisScreen(analysisId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.walletsNew,
        builder: (_, _) => const WalletFormScreen(),
      ),
      GoRoute(
        path: '/app/account/wallets/:id/edit',
        builder: (_, state) =>
            WalletFormScreen(editWalletId: state.pathParameters['id']),
      ),
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
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, _) => const ReportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (_, _) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
