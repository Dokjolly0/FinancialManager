import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

export interface TextPromptData {
  title: string;
  label: string;
  value: string;
  confirmLabel: string;
  maxLength?: number;
}

/** Asks for one line of text (renames); resolves with it trimmed, never empty. */
@Component({
  selector: 'app-text-prompt-dialog',
  imports: [ReactiveFormsModule, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <form class="p-6" (submit)="$event.preventDefault(); save()">
      <h2 class="text-lg font-semibold text-fg">{{ data.title }}</h2>
      <label class="label mt-4" for="text-prompt">{{ data.label }}</label>
      <input
        id="text-prompt"
        class="input"
        [formControl]="text"
        [maxlength]="data.maxLength ?? 200"
        cdkFocusInitial
      />
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" class="btn btn-primary" [disabled]="!text.value.trim()">
          {{ data.confirmLabel }}
        </button>
      </div>
    </form>
  `,
})
export class TextPromptDialog {
  protected readonly data = inject<TextPromptData>(DIALOG_DATA);
  protected readonly ref = inject<DialogRef<string>>(DialogRef);
  protected readonly text = new FormControl(this.data.value, { nonNullable: true });

  protected save(): void {
    const value = this.text.value.trim();
    if (value) this.ref.close(value);
  }
}
