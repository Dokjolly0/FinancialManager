import { Routes } from '@angular/router';

import { authGuard } from './core/session/guards';
import { AppShell } from './layout/app-shell';

/**
 * The same paths as the app's router (lib/app/router.dart), so bookmarks,
 * the links in emails and Android App Links keep working. Feature pages are
 * lazy chunks.
 */
export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'app/home' },
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
    ],
  },
  { path: '**', redirectTo: 'app/home' },
];
