import { DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';
import { X } from 'lucide';

import { Icon } from './icon';

/**
 * Frame of a dialog or drawer: title bar with close, scrolling body and an
 * optional `<app-sheet-footer>`. Used inside components opened through
 * Overlay.
 */
@Component({
  selector: 'app-sheet',
  imports: [Icon, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <header class="flex items-start gap-3 border-b border-border px-5 py-4">
      <div class="min-w-0 flex-1">
        <h2 class="text-base font-semibold text-fg">{{ title() }}</h2>
        @if (subtitle()) {
          <p class="mt-0.5 text-sm text-fg-muted">{{ subtitle() }}</p>
        }
      </div>
      <button
        type="button"
        class="btn btn-ghost btn-icon btn-sm -mr-1"
        [attr.aria-label]="'commonCancel' | transloco"
        (click)="ref.close()"
      >
        <app-icon [icon]="X" [size]="18" />
      </button>
    </header>
    <div class="min-h-0 flex-1 overflow-y-auto px-5 py-5">
      <ng-content />
    </div>
    <ng-content select="app-sheet-footer" />
  `,
  host: { class: 'flex h-full max-h-[inherit] flex-col' },
})
export class Sheet {
  readonly title = input.required<string>();
  readonly subtitle = input<string>();
  protected readonly ref = inject(DialogRef);
  protected readonly X = X;
}

/** Footer bar of a Sheet, with right-aligned actions. */
@Component({
  selector: 'app-sheet-footer',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: '<ng-content />',
  host: {
    class:
      'flex flex-wrap items-center justify-end gap-2 border-t border-border bg-surface px-5 py-3.5',
  },
})
export class SheetFooter {}
