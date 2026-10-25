import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ArrowLeft } from 'lucide';

import { Icon } from './icon';

/**
 * Title row of a page: optional back link, title and subtitle, actions
 * (`<ng-content>`) on the right.
 */
@Component({
  selector: 'app-page-header',
  imports: [Icon, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mb-6 flex flex-wrap items-center gap-x-4 gap-y-3">
      @if (back()) {
        <a
          [routerLink]="back()"
          class="btn btn-ghost btn-icon -ml-2"
          [attr.aria-label]="backLabel()"
        >
          <app-icon [icon]="ArrowLeft" />
        </a>
      }
      <div class="min-w-0 flex-[1_1_16rem]">
        <h1 class="truncate text-2xl font-bold tracking-tight text-fg">{{ title() }}</h1>
        @if (subtitle()) {
          <p class="mt-1 text-sm text-fg-muted">{{ subtitle() }}</p>
        }
      </div>
      <div class="flex flex-wrap items-center gap-2 empty:hidden"><ng-content /></div>
    </div>
  `,
})
export class PageHeader {
  readonly title = input.required<string>();
  readonly subtitle = input<string>();
  /** Router link of the parent page. */
  readonly back = input<string | unknown[]>();
  readonly backLabel = input('Back');
  protected readonly ArrowLeft = ArrowLeft;
}
