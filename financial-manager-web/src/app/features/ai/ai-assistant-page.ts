import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import type { IconNode } from 'lucide';
import {
  BotMessageSquare,
  ChevronRight,
  CircleCheck,
  Circle,
  History,
  ShieldCheck,
  Sparkles,
  UserRound,
  Wallet,
} from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { AiApi } from './ai.api';
import { PROVIDER_LABELS, setupSteps } from './ai.model';

interface Step {
  done: boolean;
  titleKey: string;
  hintKey: string;
  link: string;
  optional?: boolean;
}

/**
 * The AI assistant (plan.md section 32.7): the setup checklist (provider,
 * personal context, wallet purposes, first analysis), consent, the settings
 * pages and the history. The on-device step of the app is not here: models
 * can't run in a browser.
 */
@Component({
  selector: 'app-ai-assistant-page',
  imports: [EmptyState, Icon, InlineError, PageHeader, RouterLink, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-page-header
      [title]="'aiAssistantTitle' | transloco"
      back="/app/account"
      [backLabel]="'backAction' | transloco"
    >
      @if (ai.settings.value()?.available) {
        <a routerLink="/app/ai/new" class="btn btn-primary">
          <app-icon [icon]="icons.Sparkles" [size]="18" /> {{ 'aiNewAnalysisTitle' | transloco }}
        </a>
      }
    </app-page-header>

    @if (ai.settings.isLoading() && !ai.settings.hasValue()) {
      <div class="card card-pad space-y-3">
        <div class="skeleton h-6 w-1/3"></div>
        <div class="skeleton h-24 w-full"></div>
      </div>
    } @else if (ai.settings.error()) {
      <div class="card">
        <app-inline-error
          [message]="errorText.message(ai.settings.error())"
          (retry)="ai.settings.reload()"
        />
      </div>
    } @else if (ai.settings.value(); as settings) {
      @if (!settings.available) {
        <div class="card">
          <app-empty-state
            [heading]="'aiUnavailableTitle' | transloco"
            [message]="'aiUnavailableBody' | transloco"
            [icon]="icons.BotMessageSquare"
          />
        </div>
      } @else {
        <div class="grid gap-6 lg:grid-cols-5">
          <!-- Checklist -->
          <section class="card card-pad lg:col-span-3">
            <div class="flex items-center justify-between gap-3">
              <h2 class="font-semibold text-fg">
                {{
                  (progress().done === progress().total ? 'aiSetupDoneTitle' : 'aiSetupTitle')
                    | transloco
                }}
              </h2>
              <span class="text-xs font-medium text-fg-muted">
                {{
                  'aiSetupProgress' | transloco: { done: progress().done, total: progress().total }
                }}
              </span>
            </div>
            <div class="mt-3 h-1.5 overflow-hidden rounded-full bg-surface-2">
              <div
                class="h-full rounded-full bg-primary transition-all"
                [style.width.%]="(progress().done / progress().total) * 100"
              ></div>
            </div>
            <ol class="mt-5 space-y-1">
              @for (step of steps(); track step.titleKey) {
                <li>
                  <a
                    [routerLink]="step.link"
                    class="flex items-start gap-3 rounded-xl p-3 transition-colors hover:bg-surface-2"
                  >
                    <app-icon
                      [icon]="step.done ? icons.CircleCheck : icons.Circle"
                      [size]="20"
                      [class]="step.done ? 'text-credit mt-0.5' : 'text-fg-muted mt-0.5'"
                    />
                    <span class="flex-1">
                      <span
                        class="block text-sm font-medium text-fg"
                        [class.line-through]="step.done"
                        [class.opacity-70]="step.done"
                      >
                        {{ step.titleKey | transloco }}
                        @if (step.optional) {
                          <span class="text-xs font-normal text-fg-muted"
                            >· {{ 'aiSetupOptional' | transloco }}</span
                          >
                        }
                      </span>
                      <span class="block text-xs text-fg-muted">{{
                        step.hintKey | transloco
                      }}</span>
                    </span>
                    <app-icon [icon]="icons.ChevronRight" [size]="16" class="mt-1 text-fg-muted" />
                  </a>
                </li>
              }
            </ol>
          </section>

          <!-- Settings -->
          <section class="space-y-3 lg:col-span-2">
            @for (item of menu(); track item.link) {
              <a
                [routerLink]="item.link"
                class="card group flex items-center gap-3 p-4 transition-shadow hover:shadow-pop"
              >
                <span
                  class="grid h-10 w-10 place-items-center rounded-xl bg-primary-soft text-primary"
                  ><app-icon [icon]="item.icon" [size]="18"
                /></span>
                <span class="min-w-0 flex-1">
                  <span class="block text-sm font-semibold text-fg">{{
                    item.titleKey | transloco
                  }}</span>
                  <span class="block truncate text-xs text-fg-muted">{{ item.subtitle }}</span>
                </span>
                <app-icon [icon]="icons.ChevronRight" [size]="16" class="text-fg-muted" />
              </a>
            }
            <div class="card flex items-center gap-3 p-4">
              <span
                class="grid h-10 w-10 place-items-center rounded-xl bg-primary-soft text-primary"
                ><app-icon [icon]="icons.ShieldCheck" [size]="18"
              /></span>
              <span class="min-w-0 flex-1">
                <span class="block text-sm font-semibold text-fg">{{
                  'aiConsentMenuTitle' | transloco
                }}</span>
                <span class="block text-xs text-fg-muted">
                  {{
                    (settings.consent.required ? 'aiConsentMenuPending' : 'aiConsentMenuAccepted')
                      | transloco
                  }}
                </span>
              </span>
              @if (settings.consent.required) {
                <button
                  type="button"
                  class="btn btn-outline btn-sm"
                  (click)="consent(settings.consent.current_version)"
                >
                  {{ 'aiConsentAccept' | transloco }}
                </button>
              } @else {
                <button type="button" class="btn btn-danger-ghost btn-sm" (click)="revoke()">
                  {{ 'aiConsentRevokeAction' | transloco }}
                </button>
              }
            </div>
          </section>
        </div>
      }
    }
  `,
})
export class AiAssistantPage {
  protected readonly ai = inject(AiApi);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);

  protected readonly icons = {
    BotMessageSquare,
    ChevronRight,
    Circle,
    CircleCheck,
    ShieldCheck,
    Sparkles,
  };

  constructor() {
    this.ai.settings.reload();
  }

  protected readonly progress = computed(() => {
    const settings = this.ai.settings.value();
    return settings ? setupSteps(settings) : { done: 0, total: 4 };
  });

  protected readonly steps = computed<Step[]>(() => {
    const s = this.ai.settings.value()?.setup;
    if (!s) return [];
    return [
      {
        done: s.has_provider && s.has_model,
        titleKey: 'aiSetupStepProvider',
        hintKey: 'aiSetupStepProviderHint',
        link: '/app/account/ai/provider',
      },
      {
        done: s.has_context,
        titleKey: 'aiSetupStepContext',
        hintKey: 'aiSetupStepContextHint',
        link: '/app/account/ai/context',
        optional: true,
      },
      {
        done: s.wallets_total > 0 && s.wallets_with_purpose === s.wallets_total,
        titleKey: 'aiSetupStepPurposes',
        hintKey: 'aiSetupStepPurposesHint',
        link: '/app/account/ai/wallet-purposes',
        optional: true,
      },
      {
        done: s.analyses_count > 0,
        titleKey: 'aiSetupStepFirstAnalysis',
        hintKey: 'aiSetupStepFirstAnalysisHint',
        link: '/app/ai/new',
      },
    ];
  });

  protected readonly menu = computed<
    { link: string; titleKey: string; subtitle: string; icon: IconNode }[]
  >(() => {
    const settings = this.ai.settings.value();
    if (!settings) return [];
    const t = (key: string, params?: Record<string, unknown>) =>
      this.transloco.translate(key, params);
    const active = settings.active;
    return [
      {
        link: '/app/account/ai/provider',
        titleKey: 'aiProviderMenuTitle',
        subtitle: active
          ? `${PROVIDER_LABELS[active.provider] ?? t('aiProviderCompatible')}${active.model ? ' · ' + active.model : ''}`
          : t('aiProviderMenuNotConfigured'),
        icon: BotMessageSquare,
      },
      {
        link: '/app/account/ai/context',
        titleKey: 'aiContextMenuTitle',
        subtitle: t(settings.setup.has_context ? 'aiContextMenuFilled' : 'aiContextMenuEmpty'),
        icon: UserRound,
      },
      {
        link: '/app/account/ai/wallet-purposes',
        titleKey: 'aiWalletPurposesMenuTitle',
        subtitle: t('aiWalletPurposesProgress', {
          done: settings.setup.wallets_with_purpose,
          total: settings.setup.wallets_total,
        }),
        icon: Wallet,
      },
      {
        link: '/app/ai/analyses',
        titleKey: 'aiHistoryTitle',
        subtitle: t('aiHistoryMenuSubtitle'),
        icon: History,
      },
    ];
  });

  protected async consent(version: number): Promise<void> {
    const { AiConsentDialog } = await import('./ai-consent-dialog');
    await this.overlay.result<boolean, number>(AiConsentDialog, {
      data: version,
      variant: 'drawer',
    });
  }

  protected async revoke(): Promise<void> {
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('aiConsentRevokeConfirmTitle'),
      message: this.transloco.translate('aiConsentRevokeConfirmMessage'),
      confirmLabel: this.transloco.translate('aiConsentRevokeAction'),
      destructive: true,
    });
    if (!confirmed) return;
    try {
      await this.ai.revokeConsent();
    } catch (error) {
      this.toasts.error(this.errorText.message(error));
    }
  }
}
