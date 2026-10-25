import { Routes } from '@angular/router';

import {
  aiGuard,
  authGuard,
  googleCompletionGuard,
  guestGuard,
  leaveWhileStreamingGuard,
} from './core/session/guards';
import { AppShell } from './layout/app-shell';

/**
 * The same paths as the app's router (lib/app/router.dart), so bookmarks,
 * the links in emails and Android App Links keep working. Feature pages are
 * lazy chunks.
 */
export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'app/home' },
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/login-page').then((m) => m.LoginPage),
  },
  {
    path: 'register',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/register-page').then((m) => m.RegisterPage),
  },
  {
    path: 'register/google-completion',
    canActivate: [googleCompletionGuard],
    loadComponent: () =>
      import('./features/auth/google-completion-page').then((m) => m.GoogleCompletionPage),
  },
  {
    path: 'forgot-password',
    canActivate: [guestGuard],
    loadComponent: () =>
      import('./features/auth/forgot-password-page').then((m) => m.ForgotPasswordPage),
  },
  // The links in the emails ({APP_PUBLIC_URL}/reset-password?token=...):
  // open with or without a session.
  {
    path: 'reset-password',
    loadComponent: () =>
      import('./features/auth/reset-password-page').then((m) => m.ResetPasswordPage),
  },
  {
    path: 'verify-email',
    loadComponent: () => import('./features/auth/verify-email-page').then((m) => m.VerifyEmailPage),
  },
  // The app's session-restore page; restore now runs before routing.
  { path: 'splash', redirectTo: 'app/home' },
  {
    path: 'app',
    component: AppShell,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'home' },
      {
        path: 'home',
        loadComponent: () => import('./features/home/home-page').then((m) => m.HomePage),
      },
      {
        path: 'history',
        loadComponent: () => import('./features/history/history-page').then((m) => m.HistoryPage),
      },
      {
        path: 'reports',
        loadComponent: () => import('./features/reports/report-page').then((m) => m.ReportPage),
      },
      {
        path: 'transactions/new',
        loadComponent: () =>
          import('./features/transactions/transaction-form-page').then(
            (m) => m.TransactionFormPage,
          ),
      },
      {
        path: 'transactions/payment-groups',
        loadComponent: () =>
          import('./features/transactions/payment-groups-page').then((m) => m.PaymentGroupsPage),
      },
      {
        path: 'transactions/:id',
        loadComponent: () =>
          import('./features/transactions/transaction-detail-page').then(
            (m) => m.TransactionDetailPage,
          ),
      },
      {
        path: 'transactions/:id/edit',
        loadComponent: () =>
          import('./features/transactions/transaction-form-page').then(
            (m) => m.TransactionFormPage,
          ),
      },
      {
        path: 'account',
        loadComponent: () => import('./features/account/account-page').then((m) => m.AccountPage),
      },
      {
        path: 'account/profile',
        loadComponent: () => import('./features/account/profile-page').then((m) => m.ProfilePage),
      },
      {
        path: 'account/security',
        loadComponent: () => import('./features/account/security-page').then((m) => m.SecurityPage),
      },
      {
        path: 'account/linked-accounts',
        loadComponent: () =>
          import('./features/account/linked-accounts-page').then((m) => m.LinkedAccountsPage),
      },
      {
        path: 'account/preferences',
        loadComponent: () =>
          import('./features/account/preferences-page').then((m) => m.PreferencesPage),
      },
      {
        path: 'account/data',
        loadComponent: () => import('./features/account/data-page').then((m) => m.DataPage),
      },
      // AI analysis (plan.md section 32): gone when the AI features are off.
      {
        path: 'account/ai',
        canActivate: [aiGuard],
        loadComponent: () =>
          import('./features/ai/ai-assistant-page').then((m) => m.AiAssistantPage),
      },
      {
        path: 'account/ai/provider',
        canActivate: [aiGuard],
        loadComponent: () => import('./features/ai/ai-provider-page').then((m) => m.AiProviderPage),
      },
      {
        path: 'account/ai/context',
        canActivate: [aiGuard],
        loadComponent: () => import('./features/ai/ai-context-page').then((m) => m.AiContextPage),
      },
      {
        path: 'account/ai/wallet-purposes',
        canActivate: [aiGuard],
        loadComponent: () =>
          import('./features/ai/ai-wallet-purposes-page').then((m) => m.AiWalletPurposesPage),
      },
      // On-device models only exist on the phone (section 33).
      { path: 'account/ai/local-models', redirectTo: 'account/ai' },
      { path: 'account/ai/local-runtime', redirectTo: 'account/ai' },
      { path: 'ai/pending', redirectTo: 'account/ai' },
      {
        path: 'ai/new',
        canActivate: [aiGuard],
        loadComponent: () => import('./features/ai/ai-setup-page').then((m) => m.AiSetupPage),
      },
      {
        path: 'ai/preview',
        canActivate: [aiGuard],
        loadComponent: () => import('./features/ai/ai-preview-page').then((m) => m.AiPreviewPage),
      },
      {
        path: 'ai/run',
        canActivate: [aiGuard],
        canDeactivate: [leaveWhileStreamingGuard],
        loadComponent: () => import('./features/ai/ai-analysis-page').then((m) => m.AiAnalysisPage),
      },
      {
        path: 'ai/analyses',
        canActivate: [aiGuard],
        loadComponent: () => import('./features/ai/ai-history-page').then((m) => m.AiHistoryPage),
      },
      {
        path: 'ai/analyses/:id',
        canActivate: [aiGuard],
        canDeactivate: [leaveWhileStreamingGuard],
        loadComponent: () => import('./features/ai/ai-analysis-page').then((m) => m.AiAnalysisPage),
      },
      {
        path: 'account/wallets',
        loadComponent: () => import('./features/wallets/wallets-page').then((m) => m.WalletsPage),
      },
      {
        path: 'account/wallets/new',
        loadComponent: () =>
          import('./features/wallets/wallet-form-page').then((m) => m.WalletFormPage),
      },
      {
        path: 'account/wallets/:id/edit',
        loadComponent: () =>
          import('./features/wallets/wallet-form-page').then((m) => m.WalletFormPage),
      },
      // Pushed without a URL in the app; here they get one.
      {
        path: 'account/wallets/:id/denominations',
        loadComponent: () =>
          import('./features/wallets/denominations-page').then((m) => m.DenominationsPage),
      },
      {
        path: 'account/wallets/:id/voucher-lots',
        loadComponent: () =>
          import('./features/wallets/voucher-lots-page').then((m) => m.VoucherLotsPage),
      },
    ],
  },
  { path: '**', redirectTo: 'app/home' },
];
