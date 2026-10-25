import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { PasswordInput } from '../../shared/ui/password-input';

export interface PasswordPromptData {
  title: string;
  message?: string;
  label: string;
  confirmLabel: string;
  /** Google-only accounts have no password: empty is allowed. */
  optional?: boolean;
  destructive?: boolean;
}

/** Asks for the current password; resolves with it ('' when optional and left empty). */
@Component({
  selector: 'app-password-prompt-dialog',
  imports: [PasswordInput, ReactiveFormsModule, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <form class="p-6" (submit)="$event.preventDefault(); submit()">
      <h2 class="text-lg font-semibold text-fg">{{ data.title }}</h2>
      @if (data.message) {
        <p class="mt-2 text-sm leading-relaxed text-fg-muted">{{ data.message }}</p>
      }
      <label class="label mt-5" for="prompt-password">{{ data.label }}</label>
      <app-password-input
        inputId="prompt-password"
        [formControl]="password"
        autocomplete="current-password"
      />
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button
          type="submit"
          class="btn"
          [class.btn-danger]="data.destructive"
          [class.btn-primary]="!data.destructive"
          [disabled]="!data.optional && !password.value"
        >
          {{ data.confirmLabel }}
        </button>
      </div>
    </form>
  `,
})
export class PasswordPromptDialog {
  protected readonly data = inject<PasswordPromptData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<string>>(DialogRef);
  protected readonly password = new FormControl('', { nonNullable: true });

  protected submit(): void {
    if (!this.data.optional && !this.password.value) return;
    this.ref.close(this.password.value);
  }
}
