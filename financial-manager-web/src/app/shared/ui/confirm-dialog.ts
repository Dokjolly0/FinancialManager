import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';

export interface ConfirmOptions {
  title: string;
  message?: string;
  confirmLabel: string;
  cancelLabel?: string;
  /** Red confirm button for deletions and other irreversible actions. */
  destructive?: boolean;
}

/** The app's ConfirmationSheet as a dialog. */
@Component({
  selector: 'app-confirm-dialog',
  imports: [TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="p-6">
      <h2 class="text-lg font-semibold text-fg">{{ data.title }}</h2>
      @if (data.message) {
        <p class="mt-2 whitespace-pre-line text-sm leading-relaxed text-fg-muted">
          {{ data.message }}
        </p>
      }
      <div class="mt-6 flex flex-wrap justify-end gap-2">
        <button type="button" class="btn btn-ghost" (click)="ref.close(false)">
          {{ data.cancelLabel ?? ('commonCancel' | transloco) }}
        </button>
        <button
          type="button"
          class="btn"
          [class.btn-danger]="data.destructive"
          [class.btn-primary]="!data.destructive"
          (click)="ref.close(true)"
        >
          {{ data.confirmLabel }}
        </button>
      </div>
    </div>
  `,
})
export class ConfirmDialog {
  protected readonly data = inject<ConfirmOptions>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
}
