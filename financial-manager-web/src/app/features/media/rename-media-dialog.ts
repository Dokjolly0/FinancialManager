import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

/** Asks for an image's new name; resolves with it, trimmed. */
@Component({
  selector: 'app-rename-media-dialog',
  imports: [ReactiveFormsModule, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <form class="p-6" (ngSubmit)="save()">
      <h2 class="text-lg font-semibold text-fg">{{ 'mediaRenameDialogTitle' | transloco }}</h2>
      <label class="label mt-4" for="media-name">{{ 'mediaNameLabel' | transloco }}</label>
      <input id="media-name" class="input" [formControl]="name" cdkFocusInitial />
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" class="btn btn-primary">{{ 'commonSave' | transloco }}</button>
      </div>
    </form>
  `,
})
export class RenameMediaDialog {
  protected readonly ref = inject<DialogRef<string>>(DialogRef);
  protected readonly name = new FormControl(inject<string>(DIALOG_DATA), { nonNullable: true });

  protected save(): void {
    const value = this.name.value.trim();
    if (value) this.ref.close(value);
  }
}
