import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../../core/errors/form-errors';
import { MoneyPipe } from '../../../core/formatting/pipes';
import { AmountInput } from '../../../shared/ui/form-controls';
import { Sheet, SheetFooter } from '../../../shared/ui/sheet';
import { Spinner } from '../../../shared/ui/states';
import { TransactionsApi } from '../../transactions/transactions.api';
import { Wallet } from '../wallet.model';

/**
 * Balance adjustment (plan.md sections 8.4, 13.5): the user types the real
 * balance, not a difference; the backend records the gap as an adjustment.
 */
@Component({
  selector: 'app-balance-adjustment-dialog',
  imports: [
    AmountInput,
    MoneyPipe,
    ReactiveFormsModule,
    Sheet,
    SheetFooter,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet
      [title]="'accountBalanceAdjustmentAction' | transloco"
      [subtitle]="
        'currentBalanceLabel'
          | transloco: { balance: (wallet.current_balance_minor | money: wallet.currency) }
      "
    >
      <form id="adjust-form" class="space-y-5" [formGroup]="form" (ngSubmit)="submit()" novalidate>
        <div>
          <label class="label" for="adj-amount">{{ 'webNewBalanceLabel' | transloco }}</label>
          <app-amount-input
            inputId="adj-amount"
            formControlName="target"
            [large]="true"
            [currency]="wallet.currency"
            [invalid]="!!errors.fields()['target_balance_minor']"
          />
          @if (errors.fields()['target_balance_minor']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div>
          <label class="label" for="adj-reason">{{ 'reasonOptionalLabel' | transloco }}</label>
          <input id="adj-reason" class="input" formControlName="reason" />
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" form="adjust-form" class="btn btn-primary" [disabled]="saving()">
          @if (saving()) {
            <app-spinner />
          }
          {{ 'saveAdjustmentAction' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class BalanceAdjustmentDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  protected readonly wallet = inject<Wallet>(DIALOG_DATA);
  private readonly api = inject(TransactionsApi);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly form = this.fb.group({
    target: this.fb.control<number | null>(this.wallet.current_balance_minor),
    reason: [''],
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const { target, reason } = this.form.getRawValue();
    if (!this.errors.check(target === null ? { target_balance_minor: 'INVALID_AMOUNT' } : {}))
      return;
    this.saving.set(true);
    try {
      await this.api.createBalanceAdjustment(this.wallet.id, {
        target_balance_minor: target!,
        reason: reason.trim() || null,
      });
      this.ref.close(true);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
