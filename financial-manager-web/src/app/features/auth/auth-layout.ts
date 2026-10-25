import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';
import { ChartColumn, Moon, Sparkles, Sun, Wallet } from 'lucide';

import { ThemeService } from '../../core/theme/theme.service';
import { Icon } from '../../shared/ui/icon';

/**
 * Frame of the signed-out pages: a brand panel on wide screens and the form
 * card, centred, on the right.
 */
@Component({
  selector: 'app-auth-layout',
  imports: [Icon, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="grid min-h-dvh lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
      <aside
        class="relative hidden overflow-hidden bg-[#0f3d34] p-12 text-white lg:flex lg:flex-col"
      >
        <div
          class="pointer-events-none absolute -right-32 -top-32 h-96 w-96 rounded-full bg-[#65cdb5]/25 blur-3xl"
        ></div>
        <div
          class="pointer-events-none absolute -bottom-40 -left-20 h-[28rem] w-[28rem] rounded-full bg-[#176b5b]/60 blur-3xl"
        ></div>
        <div class="relative flex items-center gap-3">
          <img src="icons/Icon-192.png" alt="" width="40" height="40" class="rounded-xl" />
          <span class="text-lg font-bold tracking-tight">Financial Manager</span>
        </div>
        <div class="relative mt-auto max-w-md">
          <h2 class="text-4xl font-bold leading-tight tracking-tight">
            {{ 'webAuthTagline' | transloco }}
          </h2>
          <p class="mt-4 text-base leading-relaxed text-white/75">
            {{ 'webAuthPitch' | transloco }}
          </p>
          <ul class="mt-10 space-y-4">
            @for (feature of features; track feature.key) {
              <li class="flex items-center gap-3 text-sm font-medium text-white/90">
                <span class="grid h-9 w-9 place-items-center rounded-xl bg-white/10">
                  <app-icon [icon]="feature.icon" [size]="18" />
                </span>
                {{ feature.key | transloco }}
              </li>
            }
          </ul>
        </div>
      </aside>

      <main class="relative flex flex-col px-4 py-8 sm:px-8">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2.5 lg:invisible">
            <img src="icons/Icon-192.png" alt="" width="32" height="32" class="rounded-lg" />
            <span class="font-bold tracking-tight text-fg">Financial Manager</span>
          </div>
          <button
            type="button"
            class="btn btn-ghost btn-icon"
            [attr.aria-label]="'webToggleTheme' | transloco"
            (click)="theme.preference.set(theme.dark() ? 'light' : 'dark')"
          >
            <app-icon [icon]="theme.dark() ? Sun : Moon" />
          </button>
        </div>
        <div class="mx-auto flex w-full max-w-md flex-1 flex-col justify-center py-10">
          <h1 class="text-3xl font-bold tracking-tight text-fg">{{ heading() }}</h1>
          @if (subheading()) {
            <p class="mt-2 text-sm leading-relaxed text-fg-muted">{{ subheading() }}</p>
          }
          <div class="mt-8">
            <ng-content />
          </div>
        </div>
      </main>
    </div>
  `,
})
export class AuthLayout {
  readonly heading = input.required<string>();
  readonly subheading = input<string>();

  protected readonly theme = inject(ThemeService);
  protected readonly Sun = Sun;
  protected readonly Moon = Moon;
  protected readonly features = [
    { key: 'webAuthFeatureWallets', icon: Wallet },
    { key: 'webAuthFeatureReports', icon: ChartColumn },
    { key: 'webAuthFeatureAi', icon: Sparkles },
  ];
}
