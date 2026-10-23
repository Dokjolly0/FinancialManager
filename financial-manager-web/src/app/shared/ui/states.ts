import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';
import type { IconNode } from 'lucide';
import { CircleAlert, Inbox } from 'lucide';

import { Icon } from './icon';

/** Nothing to show yet: no data, or no match for the filters (plan.md section 7.15). */
@Component({
  selector: 'app-empty-state',
  imports: [Icon],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="flex flex-col items-center px-6 py-12 text-center">
      <div class="mb-4 grid h-14 w-14 place-items-center rounded-2xl bg-surface-2 text-fg-muted">
        <app-icon [icon]="icon()" [size]="26" />
      </div>
      @if (heading()) {
        <p class="text-sm font-semibold text-fg">{{ heading() }}</p>
      }
      <p class="mt-1 max-w-sm text-sm text-fg-muted">{{ message() }}</p>
      <div class="mt-5 empty:hidden"><ng-content /></div>
    </div>
  `,
})
export class EmptyState {
  readonly message = input.required<string>();
  readonly heading = input<string>();
  readonly icon = input<IconNode>(Inbox);
}

/** A screen or section failed to load, with retry (not a transient toast). */
@Component({
  selector: 'app-inline-error',
  imports: [Icon, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="flex flex-col items-center px-6 py-10 text-center" role="alert">
      <app-icon [icon]="CircleAlert" [size]="32" class="text-debit" />
      <p class="mt-3 max-w-sm text-sm text-fg">{{ message() }}</p>
      @if (retryable()) {
        <button type="button" class="btn btn-outline btn-sm mt-4" (click)="retry.emit()">
          {{ 'commonRetry' | transloco }}
        </button>
      }
    </div>
  `,
})
export class InlineError {
  readonly message = input.required<string>();
  readonly retryable = input(true);
  readonly retry = output<void>();
  protected readonly CircleAlert = CircleAlert;
}

/** Placeholder rows while a list loads. */
@Component({
  selector: 'app-skeleton-list',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="divide-y divide-border" aria-busy="true">
      @for (row of rowsArray(); track $index) {
        <div class="flex items-center gap-3 px-4 py-3.5">
          <div class="skeleton h-10 w-10 rounded-xl"></div>
          <div class="flex-1 space-y-2">
            <div class="skeleton h-3.5 w-2/5"></div>
            <div class="skeleton h-3 w-1/4"></div>
          </div>
          <div class="skeleton h-4 w-16"></div>
        </div>
      }
    </div>
  `,
})
export class SkeletonList {
  readonly rows = input(5);
  protected rowsArray(): number[] {
    return Array.from({ length: this.rows() });
  }
}

/** Small inline spinner for buttons and loading rows. */
@Component({
  selector: 'app-spinner',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<span
    class="inline-block animate-spin rounded-full border-2 border-current border-r-transparent"
    [style.width.px]="size()"
    [style.height.px]="size()"
    role="status"
  ></span>`,
  host: { class: 'inline-flex' },
})
export class Spinner {
  readonly size = input(16);
}
