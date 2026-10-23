import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import type { IconNode } from 'lucide';
import {
  ChevronRight,
  Database,
  KeyRound,
  Link,
  LogOut,
  MonitorSmartphone,
  Settings2,
  Sparkles,
  UserRound,
  Wallet,
} from 'lucide';

import { SessionService } from '../../core/session/session.service';
import { Avatar } from '../../shared/ui/avatar';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';

interface MenuItem {
  path: string;
  titleKey: string;
  subtitleKey?: string;
  icon: IconNode;
}

/** Account hub (plan.md section 7.13): every account setting, logout and logout everywhere. */
@Component({
  selector: 'app-account-page',
  imports: [Avatar, Icon, PageHeader, RouterLink, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-page-header [title]="'accountScreenTitle' | transloco" />

    @if (session.profile(); as profile) {
      <section class="card card-pad mb-6 flex flex-wrap items-center gap-4">
        <app-avatar
          [firstName]="profile.first_name"
          [lastName]="profile.last_name"
          [background]="profile.avatar_background_color"
          [foreground]="profile.avatar_text_color"
          [size]="64"
        />
        <div class="min-w-0 flex-1">
          <p class="truncate text-lg font-semibold text-fg">
            {{ profile.first_name }} {{ profile.last_name }}
          </p>
          <p class="truncate text-sm text-fg-muted">
            &#64;{{ profile.username }} · {{ profile.email }}
          </p>
        </div>
        <a routerLink="profile" class="btn btn-outline btn-sm">{{ 'editTooltip' | transloco }}</a>
      </section>
    }

    <div class="grid gap-3 md:grid-cols-2">
      @for (item of items(); track item.path) {
        <a
          [routerLink]="item.path"
          class="card group flex items-center gap-4 p-4 transition-shadow hover:shadow-pop"
        >
          <span
            class="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-primary-soft text-primary"
          >
            <app-icon [icon]="item.icon" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="block font-semibold text-fg">{{ item.titleKey | transloco }}</span>
            @if (item.subtitleKey) {
              <span class="block truncate text-sm text-fg-muted">{{
                item.subtitleKey | transloco
              }}</span>
            }
          </span>
          <app-icon
            [icon]="icons.ChevronRight"
            [size]="18"
            class="text-fg-muted transition-transform group-hover:translate-x-0.5"
          />
        </a>
      }
    </div>

    <section class="mt-8 flex flex-wrap gap-3">
      <button type="button" class="btn btn-outline" (click)="logout(false)">
        <app-icon [icon]="icons.LogOut" [size]="18" /> {{ 'accountLogoutAction' | transloco }}
      </button>
      <button type="button" class="btn btn-danger-ghost" (click)="logout(true)">
        <app-icon [icon]="icons.MonitorSmartphone" [size]="18" />
        {{ 'accountLogoutAllMenuTitle' | transloco }}
      </button>
    </section>
  `,
})
export class AccountPage {
  protected readonly session = inject(SessionService);
  private readonly overlay = inject(Overlay);
  private readonly transloco = inject(TranslocoService);
  protected readonly icons = { ChevronRight, LogOut, MonitorSmartphone };

  protected readonly items = computed<MenuItem[]>(() => [
    { path: 'profile', titleKey: 'accountProfileScreenTitle', icon: UserRound },
    {
      path: 'security',
      titleKey: 'accountSecurityMenuTitle',
      subtitleKey: 'accountSecurityMenuSubtitle',
      icon: KeyRound,
    },
    {
      path: 'linked-accounts',
      titleKey: 'accountLinkedAccountsMenuTitle',
      subtitleKey: 'webLinkedAccountsSubtitle',
      icon: Link,
    },
    {
      path: 'preferences',
      titleKey: 'accountPreferencesMenuTitle',
      subtitleKey: 'accountPreferencesMenuSubtitle',
      icon: Settings2,
    },
    {
      path: 'wallets',
      titleKey: 'accountWalletsMenuTitle',
      subtitleKey: 'accountWalletsMenuSubtitle',
      icon: Wallet,
    },
    {
      path: 'data',
      titleKey: 'accountDataMenuTitle',
      subtitleKey: 'accountDataMenuSubtitle',
      icon: Database,
    },
    ...(this.session.aiEnabled()
      ? [
          {
            path: 'ai',
            titleKey: 'aiAssistantMenuTitle',
            subtitleKey: 'aiAssistantMenuSubtitle',
            icon: Sparkles,
          },
        ]
      : []),
  ]);

  protected async logout(everywhere: boolean): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate(
        everywhere ? 'accountLogoutAllConfirmTitle' : 'accountLogoutConfirmTitle',
      ),
      message: everywhere ? this.transloco.translate('accountLogoutAllConfirmMessage') : undefined,
      confirmLabel: this.transloco.translate(
        everywhere ? 'accountLogoutAllAction' : 'accountLogoutAction',
      ),
      destructive: everywhere,
    });
    if (confirmed) await this.session.signOut(everywhere);
  }
}
