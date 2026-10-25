import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../core/errors/form-errors';
import { AmountInput } from '../../shared/ui/form-controls';
import { Sheet, SheetFooter } from '../../shared/ui/sheet';
import { CategorySelect } from '../categories/category-select';
import { WalletsStore } from '../wallets/wallets.store';
import { EMPTY_FILTER, HistoryFilter, TYPE_FILTERS, TypeFilter } from './history-filter';

export const TYPE_FILTER_KEYS: Record<TypeFilter, string> = {
  all: 'typeFilterAll',
  debit: 'debitsColumnLabel',
  credit: 'creditsColumnLabel',
  adjustments: 'typeFilterAdjustments',
  transfers: 'typeFilterTransfers',
};

/** Every History filter at once (the app's HistoryFiltersSheet). Resolves with the new filter. */
@Component({
  selector: 'app-history-filters-dialog',
  imports: [AmountInput, CategorySelect, ReactiveFormsModule, Sheet, SheetFooter, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet [title]="'filtersTitle' | transloco">
      <form
        id="history-filters"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="apply()"
        novalidate
      >
        <div>
          <label class="label" for="hf-type">{{ 'typeLabel' | transloco }}</label>
          <select id="hf-type" class="input" formControlName="type">
            @for (type of types; track type) {
              <option [value]="type">{{ typeKeys[type] | transloco }}</option>
            }
          </select>
        </div>
        <div>
          <label class="label" for="hf-wallet">{{ 'walletLabel' | transloco }}</label>
          <select id="hf-wallet" class="input" formControlName="walletId">
            <option [ngValue]="null">{{ 'allWalletsLabel' | transloco }}</option>
            @for (wallet of wallets.wallets(); track wallet.id) {
              <option [ngValue]="wallet.id">{{ wallet.name }}</option>
            }
          </select>
        </div>
        <div>
          <label class="label" for="hf-category">{{ 'categoryLabel' | transloco }}</label>
          <app-category-select
            inputId="hf-category"
            formControlName="categoryId"
            [allowCreate]="false"
          />
        </div>
        <div>
          <label class="label" for="hf-title">{{
            'titleOrDescriptionFilterLabel' | transloco
          }}</label>
          <input id="hf-title" class="input" formControlName="title" />
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label class="label" for="hf-min">{{ 'minAmountLabel' | transloco }}</label>
            <app-amount-input inputId="hf-min" formControlName="amountMin" />
          </div>
          <div>
            <label class="label" for="hf-max">{{ 'maxAmountLabel' | transloco }}</label>
            <app-amount-input inputId="hf-max" formControlName="amountMax" />
          </div>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label class="label" for="hf-from">{{ 'startDateLabel' | transloco }}</label>
            <input id="hf-from" type="date" class="input" formControlName="from" />
          </div>
          <div>
            <label class="label" for="hf-to">{{ 'endDateLabel' | transloco }}</label>
            <input
              id="hf-to"
              type="date"
              class="input"
              formControlName="to"
              [min]="form.controls.from.value"
            />
          </div>
        </div>
        @if (errors.fields()['range']; as m) {
          <p class="field-error">{{ m }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost mr-auto" (click)="reset()">
          {{ 'resetAction' | transloco }}
        </button>
        <button type="submit" form="history-filters" class="btn btn-primary">
          {{ 'applyAction' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class HistoryFiltersDialog {
  private readonly ref = inject<DialogRef<HistoryFilter>>(DialogRef);
  private readonly initial = inject<HistoryFilter>(DIALOG_DATA);
  protected readonly wallets = inject(WalletsStore);
  protected readonly types = TYPE_FILTERS;
  protected readonly typeKeys = TYPE_FILTER_KEYS;
  protected readonly errors = new FormErrors();

  private readonly fb = inject(NonNullableFormBuilder);
  protected readonly form = this.fb.group({
    type: this.fb.control<TypeFilter>(this.initial.type),
    walletId: this.fb.control<string | null>(this.initial.walletId),
    categoryId: this.fb.control<string | null>(this.initial.categoryId),
    title: [this.initial.title],
    amountMin: this.fb.control<number | null>(this.initial.amountMin),
    amountMax: this.fb.control<number | null>(this.initial.amountMax),
    from: [this.initial.from ?? ''],
    to: [this.initial.to ?? ''],
  });

  protected reset(): void {
    this.ref.close(EMPTY_FILTER);
  }

  protected apply(): void {
    const v = this.form.getRawValue();
    if (v.from && v.to && v.to < v.from) {
      this.errors.check({ range: 'webEndBeforeStart' });
      return;
    }
    this.ref.close({ ...v, from: v.from || null, to: v.to || null });
  }
}
