import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { TranslocoPipe } from '@jsverse/transloco';
import { EllipsisVertical, Plus } from 'lucide';

import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, SkeletonList } from '../../shared/ui/states';
import { CategoriesStore, Category } from './categories.store';
import { CategoryActions } from './category-actions';
import { CategorySortToggle } from './category-sort-toggle';

interface Section {
  titleKey: string;
  hintKey?: string;
  categories: Category[];
}

/**
 * Category management (plan.md section 7.13), from Account: expense and
 * income categories in the shared order, then the hidden system ones.
 * Clicking a category opens its actions.
 */
@Component({
  selector: 'app-categories-page',
  imports: [CategorySortToggle, Icon, InlineError, PageHeader, SkeletonList, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-page-header
      [title]="'categoriesScreenTitle' | transloco"
      [subtitle]="'categoriesMenuSubtitle' | transloco"
    >
      <button type="button" class="btn btn-primary" (click)="actions.create()">
        <app-icon [icon]="icons.Plus" [size]="18" />
        {{ 'newCategoryAction' | transloco }}
      </button>
    </app-page-header>

    <app-category-sort-toggle class="mb-6 max-w-sm" />

    @if (store.loading()) {
      <div class="card overflow-hidden"><app-skeleton-list [rows]="5" /></div>
    } @else if (store.error() && !store.loaded()) {
      <div class="card">
        <app-inline-error [message]="'categoriesLoadError' | transloco" (retry)="store.reload()" />
      </div>
    } @else {
      <div class="grid items-start gap-6 lg:grid-cols-2">
        @for (section of sections(); track section.titleKey) {
          <section [class]="section.hintKey ? 'lg:col-span-2' : ''">
            <h2 class="section-title mb-2">{{ section.titleKey | transloco }}</h2>
            @if (section.hintKey) {
              <p class="mb-2 text-sm text-fg-muted">{{ section.hintKey | transloco }}</p>
            }
            <ul class="card divide-y divide-border overflow-hidden">
              @for (category of section.categories; track category.id) {
                <li>
                  <button
                    type="button"
                    class="list-row w-full text-left"
                    (click)="actions.open(category)"
                  >
                    <span
                      class="grid h-9 w-9 shrink-0 place-items-center rounded-full text-sm font-semibold"
                      [class.bg-surface-2]="!category.color"
                      [class.text-fg]="!category.color"
                      [class.text-white]="!!category.color"
                      [style.background-color]="category.color"
                    >
                      {{ initial(category) }}
                    </span>
                    <span class="min-w-0 flex-1">
                      <span class="block truncate font-medium text-fg">{{ category.name }}</span>
                      <span class="block text-xs text-fg-muted">
                        {{ 'categoryUsageCount' | transloco: { count: category.usage_count ?? 0 } }}
                        @if (category.is_system) {
                          · {{ 'categorySystemLabel' | transloco }}
                        }
                      </span>
                    </span>
                    <app-icon [icon]="icons.EllipsisVertical" [size]="18" class="text-fg-muted" />
                  </button>
                </li>
              }
            </ul>
          </section>
        }
      </div>
    }
  `,
})
export class CategoriesPage {
  protected readonly store = inject(CategoriesStore);
  protected readonly actions = inject(CategoryActions);
  protected readonly icons = { EllipsisVertical, Plus };

  protected readonly sections = computed<Section[]>(() => {
    const all = this.store.categories();
    const visible = all.filter((c) => !c.hidden);
    const hidden = all.filter((c) => c.hidden);
    return [
      {
        titleKey: 'categoryScopeDebit',
        categories: visible.filter((c) => c.direction_scope !== 'CREDIT'),
      },
      {
        titleKey: 'categoryScopeCredit',
        categories: visible.filter((c) => c.direction_scope !== 'DEBIT'),
      },
      ...(hidden.length
        ? [
            {
              titleKey: 'categoriesHiddenSection',
              hintKey: 'categoriesHiddenHint',
              categories: hidden,
            },
          ]
        : []),
    ];
  });

  protected initial(category: Category): string {
    return category.name.charAt(0).toUpperCase() || '?';
  }
}
