import { DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../../core/errors/form-errors';
import { fromDateTimeInput, toDateTimeInput } from '../../../core/formatting/dates';
import { AmountInput } from '../../../shared/ui/form-controls';
import { Sheet, SheetFooter } from '../../../shared/ui/sheet';
import { Spinner } from '../../../shared/ui/states';
import { TransactionsApi } from '../../transactions/transactions.api';
import { WalletSelect } from '../wallet-select';

/**
 * Atomic wallet-to-wallet transfer: two wallets and an amount, no category
 * or title, since a transfer is neither an expense nor an income and never
 * counts in report totals.
 */
@Component({
  selector: 'app-transfer-dialog',
  imports: [
    AmountInput,
    ReactiveFormsModule,
    Sheet,
    SheetFooter,
    Spinner,
    TranslocoPipe,
    WalletSelect,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet [title]="'transferSheetTitle' | transloco">
      <form
        id="transfer-form"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="submit()"
        novalidate
      >
        <div>
          <p class="label">{{ 'transferSourceWalletLabel' | transloco }}</p>
          <app-wallet-select
            formControlName="source"
            [label]="'transferSourceWalletLabel' | transloco"
          />
        </div>
        <div>
          <p class="label">{{ 'transferDestinationWalletLabel' | transloco }}</p>
          <app-wallet-select
            formControlName="destination"
            [exclude]="values().source ?? null"
            [label]="'transferDestinationWalletLabel' | transloco"
          />
          @if (errors.fields()['wallets']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div class="grid gap-5 sm:grid-cols-2">
          <div>
            <label class="label" for="tr-amount">{{ 'transferAmountLabel' | transloco }}</label>
            <app-amount-input
              inputId="tr-amount"
              formControlName="amount"
              [invalid]="!!errors.fields()['amount_minor']"
            />
            @if (errors.fields()['amount_minor']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          <div>
            <label class="label" for="tr-date">{{ 'dateAndTimeLabel' | transloco }}</label>
            <input id="tr-date" type="datetime-local" class="input" formControlName="occurredAt" />
          </div>
        </div>
        <div>
          <label class="label" for="tr-note">{{ 'transferNoteLabel' | transloco }}</label>
          <input id="tr-note" class="input" formControlName="note" />
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button type="submit" form="transfer-form" class="btn btn-primary" [disabled]="saving()">
          @if (saving()) {
            <app-spinner />
          }
          {{ 'submitTransferAction' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class TransferDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  private readonly api = inject(TransactionsApi);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly form = this.fb.group({
    source: this.fb.control<string | null>(null),
    destination: this.fb.control<string | null>(null),
    amount: this.fb.control<number | null>(null),
    occurredAt: [toDateTimeInput(new Date())],
    note: [''],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (v.amount === null || v.amount <= 0) codes['amount_minor'] = 'INVALID_AMOUNT';
    if (!v.source || !v.destination) codes['wallets'] = 'selectWalletPlaceholder';
    else if (v.source === v.destination) codes['wallets'] = 'transferSameWalletError';
    if (!this.errors.check(codes)) return;
    this.saving.set(true);
    try {
      await this.api.createTransfer({
        source_wallet_id: v.source!,
        destination_wallet_id: v.destination!,
        amount_minor: v.amount!,
        note: v.note.trim() || null,
        occurred_at: (fromDateTimeInput(v.occurredAt) ?? new Date()).toISOString(),
      });
      this.ref.close(true);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
