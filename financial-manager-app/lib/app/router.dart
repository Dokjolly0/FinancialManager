import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/screens/account_data_screen.dart';
import '../features/account/presentation/screens/account_linked_accounts_screen.dart';
import '../features/account/presentation/screens/account_preferences_screen.dart';
import '../features/account/presentation/screens/account_profile_screen.dart';
import '../features/account/presentation/screens/account_screen.dart';
import '../features/account/presentation/screens/account_security_screen.dart';
import '../features/account/presentation/view_models/account_providers.dart';
import '../features/ai/presentation/view_models/local_run_plan.dart';
import '../features/ai/presentation/screens/ai_analysis_screen.dart';
import '../features/ai/presentation/screens/ai_analysis_setup_screen.dart';
import '../features/ai/presentation/screens/ai_assistant_screen.dart';
import '../features/ai/presentation/screens/ai_history_screen.dart';
import '../features/ai/presentation/screens/ai_local_models_screen.dart';
import '../features/ai/presentation/screens/ai_local_runtime_screen.dart';
import '../features/ai/presentation/screens/ai_pending_results_screen.dart';
import '../features/ai/presentation/screens/ai_prompt_preview_screen.dart';
import '../features/ai/presentation/screens/ai_personal_context_screen.dart';
import '../features/ai/presentation/screens/ai_provider_settings_screen.dart';
import '../features/ai/presentation/screens/ai_wallet_purposes_screen.dart';
import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/reset_password_screen.dart';
import '../features/authentication/presentation/screens/verify_email_screen.dart';
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
import 'layout/breakpoints.dart';
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

  // Links in emails (`?token=...`): open on the web dashboard and, through
  // Android App Links, in the app. Reachable signed in or not.
  static const resetPassword = '/reset-password';
  static const verifyEmail = '/verify-email';

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

  // On-device models (plan.md section 33).
  static const aiLocalModels = '/app/account/ai/local-models';
  static const aiLocalRuntime = '/app/account/ai/local-runtime';

  // AI analysis flow: setup → preview → run, plus the history.
  static const aiNew = '/app/ai/new';
  static const aiPreview = '/app/ai/preview';
  static const aiRun = '/app/ai/run';
  static const aiHistory = '/app/ai/analyses';
  static const aiPending = '/app/ai/pending';
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
      final isEmailLink = _isEmailLinkPath(path);
      // Where the splash was asked to go back to after restoring the session.
      final from = path == AppRoutes.splash
          ? state.uri.queryParameters['from']
          : null;

      switch (status) {
        case SessionStatus.checking:
          // Keep where the user was going (a reload or a link in the
          // browser), to land there once the session is restored.
          if (path == AppRoutes.splash) return null;
          return Uri(
            path: AppRoutes.splash,
            queryParameters: {'from': state.uri.toString()},
          ).toString();
        case SessionStatus.unauthenticated:
          if (isEmailLink) return null;
          if (from != null && _isEmailLinkPath(Uri.parse(from).path)) {
            return from;
          }
          return isAuthRoute && path != AppRoutes.splash
              ? null
              : AppRoutes.login;
        case SessionStatus.profileIncomplete:
          return path == AppRoutes.registerGoogleCompletion || isEmailLink
              ? null
              : AppRoutes.registerGoogleCompletion;
        case SessionStatus.authenticated:
          if (isEmailLink) return null;
          if (isAuthRoute) {
            return from != null &&
                    (from.startsWith('/app/') ||
                        _isEmailLinkPath(Uri.parse(from).path))
                ? from
                : AppRoutes.home;
          }
          // AI features turned off (section 32.10): their screens are
          // gone too, even from a stale link.
          final aiOff =
              ref.read(accountProfileProvider).value?.aiEnabled == false;
          if (aiOff &&
              (path.startsWith('/app/ai') ||
                  path.startsWith(AppRoutes.aiAssistant))) {
            return AppRoutes.account;
          }
          // Model management and the phone's outbox don't exist where
          // models can't run (the web dashboard).
          if (!ref.read(localAiSupportedProvider) &&
              (path == AppRoutes.aiLocalModels ||
                  path == AppRoutes.aiLocalRuntime ||
                  path == AppRoutes.aiPending)) {
            return AppRoutes.aiAssistant;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const AdaptivePage(child: SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const AdaptivePage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const AdaptivePage(child: RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const AdaptivePage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, state) => AdaptivePage(
          child: ResetPasswordScreen(token: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => AdaptivePage(
          child: VerifyEmailScreen(token: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: AppRoutes.registerGoogleCompletion,
        builder: (_, _) =>
            const AdaptivePage(child: GoogleRegistrationCompletionScreen()),
      ),
      GoRoute(
        path: AppRoutes.transactionsNew,
        builder: (_, state) => AdaptivePage(
          child: NewTransactionScreen(
            linkToTransactionId: state.uri.queryParameters['linkTo'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentGroups,
        builder: (_, _) => const AdaptivePage(child: PaymentGroupsScreen()),
      ),
      GoRoute(
        path: '/app/transactions/:id',
        builder: (_, state) => AdaptivePage(
          child: TransactionDetailScreen(
            transactionId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/app/transactions/:id/edit',
        builder: (_, state) => AdaptivePage(
          child: NewTransactionScreen(
            editTransactionId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.accountProfile,
        builder: (_, _) => const AdaptivePage(child: AccountProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.accountSecurity,
        builder: (_, _) => const AdaptivePage(child: AccountSecurityScreen()),
      ),
      GoRoute(
        path: AppRoutes.accountLinkedAccounts,
        builder: (_, _) =>
            const AdaptivePage(child: AccountLinkedAccountsScreen()),
      ),
      GoRoute(
        path: AppRoutes.accountPreferences,
        builder: (_, _) =>
            const AdaptivePage(child: AccountPreferencesScreen()),
      ),
      GoRoute(
        path: AppRoutes.accountData,
        builder: (_, _) => const AdaptivePage(child: AccountDataScreen()),
      ),
      GoRoute(
        path: AppRoutes.wallets,
        builder: (_, _) => const AdaptivePage(child: WalletsScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (_, _) => const AdaptivePage(child: AiAssistantScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiProvider,
        builder: (_, _) =>
            const AdaptivePage(child: AiProviderSettingsScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiContext,
        builder: (_, _) => const AdaptivePage(child: AiPersonalContextScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiWalletPurposes,
        builder: (_, _) => const AdaptivePage(child: AiWalletPurposesScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiLocalModels,
        builder: (_, _) => const AdaptivePage(child: AiLocalModelsScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiLocalRuntime,
        builder: (_, _) => const AdaptivePage(child: AiLocalRuntimeScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiNew,
        builder: (_, _) => const AdaptivePage(child: AiAnalysisSetupScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiPreview,
        builder: (_, _) => const AdaptivePage(child: AiPromptPreviewScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiRun,
        builder: (_, _) => const AdaptivePage(child: AiAnalysisScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiPending,
        builder: (_, _) => const AdaptivePage(child: AiPendingResultsScreen()),
      ),
      GoRoute(
        path: AppRoutes.aiHistory,
        builder: (_, _) => const AdaptivePage(child: AiHistoryScreen()),
      ),
      GoRoute(
        path: '/app/ai/analyses/:id',
        builder: (_, state) => AdaptivePage(
          child: AiAnalysisScreen(analysisId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: AppRoutes.walletsNew,
        builder: (_, _) => const AdaptivePage(child: WalletFormScreen()),
      ),
      GoRoute(
        path: '/app/account/wallets/:id/edit',
        builder: (_, state) => AdaptivePage(
          child: WalletFormScreen(editWalletId: state.pathParameters['id']),
        ),
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

bool _isEmailLinkPath(String path) =>
    path == AppRoutes.resetPassword || path == AppRoutes.verifyEmail;
