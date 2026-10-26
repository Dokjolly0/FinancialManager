import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';
import { Ban, Check } from 'lucide';

import { FormErrors } from '../../core/errors/form-errors';
import { Segmented, SegmentOption } from '../../shared/ui/form-controls';
import { Icon } from '../../shared/ui/icon';
import { Sheet, SheetFooter } from '../../shared/ui/sheet';
import { Spinner } from '../../shared/ui/states';
import { WALLET_COLORS } from '../wallets/wallet.model';
import { CategoriesStore, Category, CategoryScope } from './categories.store';

export interface CategoryEditData {
  /** The user's own category to edit; absent to create one. */
  category?: Category;
  scope?: CategoryScope;
}

/**
 * Creates or edits a category (the app's CategoryEditSheet): name, which
 * directions it's used for, color. Closes with the saved category.
 */
@Component({
  selector: 'app-category-edit-dialog',
  imports: [Icon, ReactiveFormsModule, Segmented, Sheet, SheetFooter, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet [title]="(data.category ? 'editCategoryTitle' : 'newCategoryAction') | transloco">
      <form
        id="category-form"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="submit()"
        novalidate
      >
        <div>
          <label class="label" for="category-name">{{ 'categoryNameLabel' | transloco }}</label>
          <input
            id="category-name"
            class="input"
            formControlName="name"
            maxlength="80"
            autocomplete="off"
            [attr.aria-invalid]="!!errors.fields()['name']"
          />
          @if (errors.fields()['name']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div>
          <p class="label">{{ 'categoryScopeLabel' | transloco }}</p>
          <app-segmented
            [options]="scopes"
            [label]="'categoryScopeLabel' | transloco"
            formControlName="direction_scope"
          />
        </div>
        <div>
          <p class="label">{{ 'categoryColorLabel' | transloco }}</p>
          <div class="flex flex-wrap gap-2" role="radiogroup">
            <button
              type="button"
              role="radio"
              class="swatch bg-surface-2 text-fg-muted"
              [attr.aria-checked]="form.controls.color.value === null"
              [attr.aria-label]="'categoryNoColor' | transloco"
              [title]="'categoryNoColor' | transloco"
              (click)="form.controls.color.setValue(null)"
            >
              <app-icon [icon]="icons.Ban" [size]="16" />
            </button>
            @for (color of colors; track color) {
              <button
                type="button"
                role="radio"
                class="swatch text-white"
                [style.background-color]="color"
                [attr.aria-checked]="form.controls.color.value === color"
                [attr.aria-label]="color"
                (click)="form.controls.color.setValue(color)"
              >
                @if (form.controls.color.value === color) {
                  <app-icon [icon]="icons.Check" [size]="16" />
                }
              </button>
            }
          </div>
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" form="category-form" class="btn btn-primary" [disabled]="saving()">
          @if (saving()) {
            <app-spinner />
          }
          {{ 'commonSave' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
  styles: `
    .swatch {
      display: grid;
      place-items: center;
      height: 2.25rem;
      width: 2.25rem;
      border-radius: 9999px;
      outline-offset: 2px;
    }
    .swatch[aria-checked='true'] {
      outline: 2px solid var(--c-fg);
    }
  `,
})
export class CategoryEditDialog {
  protected readonly ref = inject<DialogRef<Category>>(DialogRef);
  protected readonly data = inject<CategoryEditData>(DIALOG_DATA);
  private readonly store = inject(CategoriesStore);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly icons = { Ban, Check };
  protected readonly colors = WALLET_COLORS;
  protected readonly scopes: SegmentOption<CategoryScope>[] = [
    { value: 'DEBIT', labelKey: 'categoryScopeDebit' },
    { value: 'CREDIT', labelKey: 'categoryScopeCredit' },
    { value: 'BOTH', labelKey: 'categoryScopeBoth' },
  ];
  protected readonly form = this.fb.group({
    name: [this.data.category?.name ?? ''],
    direction_scope: [this.data.category?.direction_scope ?? this.data.scope ?? 'DEBIT'],
    color: this.fb.control<string | null>(this.data.category?.color?.toUpperCase() ?? null),
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const { name, direction_scope, color } = this.form.getRawValue();
    if (!this.errors.check(name.trim() ? {} : { name: 'CATEGORY_NAME_LENGTH_INVALID' })) return;
    this.saving.set(true);
    try {
      const saved = await this.store.save(this.data.category?.id ?? null, {
        name: name.trim(),
        direction_scope,
        color,
      });
      this.ref.close(saved);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
