import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, Injectable, inject } from '@angular/core';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Eye, EyeOff, Pencil, Trash2 } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { Sheet } from '../../shared/ui/sheet';
import { Toasts } from '../../shared/ui/toast';
import { CategoriesStore, Category, CategoryScope } from './categories.store';
import { CategoryEditData, CategoryEditDialog } from './category-edit-dialog';

type CategoryAction = 'edit' | 'delete' | 'hide' | 'unhide';

/**
 * What can be done with a category (the app's CategoryActionsSheet), from
 * the Categories page and the picker: edit or delete the user's own, hide
 * or show again a system one.
 */
@Injectable({ providedIn: 'root' })
export class CategoryActions {
  private readonly overlay = inject(Overlay);
  private readonly store = inject(CategoriesStore);
  private readonly transloco = inject(TranslocoService);
  private readonly errors = inject(ErrorText);
  private readonly toasts = inject(Toasts);

  /** Shows the category's actions and runs the chosen one. */
  async open(category: Category): Promise<void> {
    const action = await this.overlay.result<CategoryAction, Category>(CategoryActionsDialog, {
      data: category,
    });
    switch (action) {
      case 'edit':
        await this.edit(category);
        break;
      case 'delete':
        await this.remove(category);
        break;
      case 'hide':
      case 'unhide':
        await this.run(() => this.store.setHidden(category.id, action === 'hide'));
        break;
    }
  }

  /** New category; resolves with it, or undefined if dismissed. */
  create(scope: CategoryScope = 'DEBIT'): Promise<Category | undefined> {
    return this.overlay.result<Category, CategoryEditData>(CategoryEditDialog, {
      data: { scope },
    });
  }

  edit(category: Category): Promise<Category | undefined> {
    return this.overlay.result<Category, CategoryEditData>(CategoryEditDialog, {
      data: { category },
    });
  }

  /** Asks first, saying how many operations will be left without a category. */
  async remove(category: Category): Promise<void> {
    const t = (key: string, params?: Record<string, unknown>) =>
      this.transloco.translate(key, params);
    const count = category.usage_count ?? 0;
    const confirmed = await this.overlay.confirm({
      title: t('deleteCategoryConfirmTitle', { name: category.name }),
      message:
        count > 0 ? t('deleteCategoryInUseMessage', { count }) : t('deleteCategoryUnusedMessage'),
      confirmLabel: t('commonDelete'),
      destructive: true,
    });
    if (confirmed) await this.run(() => this.store.remove(category.id));
  }

  private async run(action: () => Promise<void>): Promise<void> {
    try {
      await action();
    } catch (error) {
      this.toasts.error(this.errors.message(error));
    }
  }
}

@Component({
  selector: 'app-category-actions-dialog',
  imports: [Icon, Sheet, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet
      [title]="category.name"
      [subtitle]="'categoryUsageCount' | transloco: { count: category.usage_count ?? 0 }"
    >
      <div class="-mx-2 space-y-1">
        @if (category.is_system) {
          <p class="px-2 pb-2 text-sm text-fg-muted">
            {{ 'systemCategoryActionsHint' | transloco }}
          </p>
          @if (category.hidden) {
            <button type="button" class="action" (click)="ref.close('unhide')">
              <app-icon [icon]="icons.Eye" [size]="18" />
              {{ 'unhideCategoryAction' | transloco }}
            </button>
          } @else {
            <button type="button" class="action" (click)="ref.close('hide')">
              <app-icon [icon]="icons.EyeOff" [size]="18" />
              {{ 'hideCategoryAction' | transloco }}
            </button>
          }
        } @else {
          <button type="button" class="action" (click)="ref.close('edit')">
            <app-icon [icon]="icons.Pencil" [size]="18" />
            {{ 'editCategoryAction' | transloco }}
          </button>
          <button type="button" class="action text-debit" (click)="ref.close('delete')">
            <app-icon [icon]="icons.Trash2" [size]="18" />
            {{ 'commonDelete' | transloco }}
          </button>
        }
      </div>
    </app-sheet>
  `,
  styles: `
    .action {
      display: flex;
      width: 100%;
      align-items: center;
      gap: 0.75rem;
      border-radius: 0.625rem;
      padding: 0.7rem 0.75rem;
      text-align: left;
      font-size: 0.9rem;
      font-weight: 500;
    }
    .action:hover,
    .action:focus-visible {
      background: var(--c-surface-2);
      outline: none;
    }
  `,
})
export class CategoryActionsDialog {
  protected readonly ref = inject<DialogRef<CategoryAction>>(DialogRef);
  protected readonly category = inject<Category>(DIALOG_DATA);
  protected readonly icons = { Eye, EyeOff, Pencil, Trash2 };
}
