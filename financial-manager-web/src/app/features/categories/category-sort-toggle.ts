import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { Segmented, SegmentOption } from '../../shared/ui/form-controls';
import { CategoriesStore } from './categories.store';
import { CategorySort } from './category-sort';

/** "A–Z / Più usate" for category lists; the choice is shared and remembered. */
@Component({
  selector: 'app-category-sort-toggle',
  host: { class: 'block' },
  imports: [FormsModule, Segmented, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-segmented
      [options]="options"
      [stretch]="stretch()"
      [label]="'categorySortMostUsed' | transloco"
      [ngModel]="store.sort()"
      (ngModelChange)="store.setSort($event)"
    />
  `,
})
export class CategorySortToggle {
  readonly stretch = input(true);
  protected readonly store = inject(CategoriesStore);
  protected readonly options: SegmentOption<CategorySort>[] = [
    { value: 'alphabetical', labelKey: 'categorySortAlphabetical' },
    { value: 'mostUsed', labelKey: 'categorySortMostUsed' },
  ];
}
