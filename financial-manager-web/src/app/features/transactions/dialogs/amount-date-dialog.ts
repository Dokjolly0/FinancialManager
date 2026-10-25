import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../../core/errors/form-errors';
import { fromDateTimeInput, toDateTimeInput } from '../../../core/formatting/dates';
import { AmountInput } from '../../../shared/ui/form-controls';
import { Sheet, SheetFooter } from '../../../shared/ui/sheet';
import { Spinner } from '../../../shared/ui/states';
import { Transaction } from '../transaction.model';
import { TransactionsApi } from '../transactions.api';

export interface AmountDateData {
  transaction: Transaction;
  /** Opening balance or transfer: the two rows whose amount and date can change. */
  mode: 'opening-balance' | 'transfer';
}

/**
 * Corrects the amount and date of an opening balance or of a transfer
 * (the app's OpeningBalanceEditSheet and TransferEditSheet). Everything
 * else stays fixed: wallets are structural to a transfer's pair, and an
 * opening balance is the wallet's starting point, not an adjustment.
 */
@Component({
  selector: 'app-amount-date-dialog',
  imports: [AmountInput, ReactiveFormsModule, Sheet, SheetFooter, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet
      [title]="
        (data.mode === 'transfer' ? 'editTransferSheetTitle' : 'editOpeningBalanceSheetTitle')
          | transloco
      "
    >
      <form
        id="amount-date-form"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="submit()"
        novalidate
      >
        @if (data.mode === 'opening-balance') {
          <p class="rounded-xl bg-surface-2 px-4 py-3 text-sm leading-relaxed text-fg-muted">
            {{ 'editOpeningBalanceHint' | transloco }}
          </p>
        }
        <div>
          <label class="label" for="ad-amount">{{ 'webAmountLabel' | transloco }}</label>
          <app-amount-input
            inputId="ad-amount"
            formControlName="amount"
            [large]="true"
            [currency]="data.transaction.currency"
            [invalid]="!!errors.fields()['amount_minor']"
          />
          @if (errors.fields()['amount_minor']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div>
          <label class="label" for="ad-date">{{ 'dateAndTimeLabel' | transloco }}</label>
          <input id="ad-date" type="datetime-local" class="input" formControlName="occurredAt" />
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" form="amount-date-form" class="btn btn-primary" [disabled]="saving()">
          @if (saving()) {
            <app-spinner />
          }
          {{
            (data.mode === 'transfer' ? 'saveTransferAction' : 'saveOpeningBalanceAction')
              | transloco
          }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class AmountDateDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  protected readonly data = inject<AmountDateData>(DIALOG_DATA);
  private readonly api = inject(TransactionsApi);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly form = this.fb.group({
    amount: this.fb.control<number | null>(this.data.transaction.amount_minor),
    occurredAt: [toDateTimeInput(new Date(this.data.transaction.occurred_at))],
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const { amount, occurredAt } = this.form.getRawValue();
    const positive = this.data.mode === 'transfer';
    const invalid = amount === null || (positive && amount <= 0);
    if (!this.errors.check(invalid ? { amount_minor: 'INVALID_AMOUNT' } : {})) return;
    const body = {
      amount_minor: amount!,
      occurred_at: (fromDateTimeInput(occurredAt) ?? new Date()).toISOString(),
      version: this.data.transaction.version,
    };
    this.saving.set(true);
    try {
      if (this.data.mode === 'transfer')
        await this.api.updateTransfer(this.data.transaction.id, body);
      else await this.api.updateOpeningBalance(this.data.transaction.id, body);
      this.ref.close(true);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
