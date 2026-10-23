import { CdkMenu, CdkMenuItem, CdkMenuTrigger } from '@angular/cdk/menu';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import type { IconNode } from 'lucide';
import {
  ChartColumn,
  ChevronsLeft,
  ChevronsRight,
  History,
  House,
  LogOut,
  Moon,
  Plus,
  Search,
  Sparkles,
  Sun,
  User,
  Wallet,
} from 'lucide';

import { SessionService } from '../core/session/session.service';
import { AccountApi } from '../features/account/account.api';
import { ThemeService } from '../core/theme/theme.service';
import { Avatar } from '../shared/ui/avatar';
import { Icon } from '../shared/ui/icon';
import { Overlay } from '../shared/ui/overlay';
import { AddActions } from './add-actions';
import { CommandPalette } from './command-palette';

export interface NavItem {
  path: string;
  labelKey: string;
  icon: IconNode;
  /** Shown in the phone's bottom bar. */
  mobile: boolean;
}

const COLLAPSED_KEY = 'fm.sidebar.collapsed';

/**
 * Signed-in layout (plan.md section 5.1): a sidebar with the destinations
 * and "Aggiungi" on wide screens (icons only when collapsed or on tablets),
 * a bottom bar with a centre "+" on phones, and a top bar with search
 * (Ctrl+K), theme and the user menu.
 */
@Component({
  selector: 'app-shell',
  imports: [
    Avatar,
    CdkMenu,
    CdkMenuItem,
    CdkMenuTrigger,
    Icon,
    RouterLink,
    RouterLinkActive,
    RouterOutlet,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './app-shell.html',
  host: { '(document:keydown)': 'onKeydown($event)' },
})
export class AppShell {
  protected readonly session = inject(SessionService);
  protected readonly theme = inject(ThemeService);
  protected readonly add = inject(AddActions);
  private readonly overlay = inject(Overlay);
  private readonly transloco = inject(TranslocoService);
  private readonly account = inject(AccountApi);

  protected readonly collapsed = signal(readCollapsed());

  protected readonly nav = computed<NavItem[]>(() => [
    { path: '/app/home', labelKey: 'webNavHome', icon: House, mobile: true },
    { path: '/app/history', labelKey: 'webNavHistory', icon: History, mobile: true },
    { path: '/app/reports', labelKey: 'webNavReports', icon: ChartColumn, mobile: true },
    { path: '/app/account/wallets', labelKey: 'walletsScreenTitle', icon: Wallet, mobile: false },
    ...(this.session.aiEnabled()
      ? [{ path: '/app/account/ai', labelKey: 'aiAssistantTitle', icon: Sparkles, mobile: false }]
      : []),
    { path: '/app/account', labelKey: 'accountScreenTitle', icon: User, mobile: true },
  ]);
  protected readonly mobileNav = computed(() => this.nav().filter((item) => item.mobile));

  protected readonly icons = { ChevronsLeft, ChevronsRight, LogOut, Moon, Plus, Search, Sun };

  protected toggleCollapsed(): void {
    this.collapsed.update((value) => !value);
    try {
      localStorage.setItem(COLLAPSED_KEY, this.collapsed() ? '1' : '0');
    } catch {
      // Storage blocked: the choice lasts for this page.
    }
  }

  /** Switches theme at once and saves it in the profile (best effort). */
  protected toggleTheme(): void {
    const theme = this.theme.dark() ? 'light' : 'dark';
    this.theme.preference.set(theme);
    this.account.updateProfile({ theme }).catch(() => undefined);
  }

  protected openPalette(): void {
    this.overlay.open(CommandPalette, { data: { nav: this.nav() } });
  }

  protected onKeydown(event: KeyboardEvent): void {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault();
      this.openPalette();
    }
  }

  protected async signOut(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('accountLogoutConfirmTitle'),
      confirmLabel: this.transloco.translate('accountLogoutAction'),
    });
    if (confirmed) await this.session.signOut();
  }
}

function readCollapsed(): boolean {
  try {
    return localStorage.getItem(COLLAPSED_KEY) === '1';
  } catch {
    return false;
  }
}
