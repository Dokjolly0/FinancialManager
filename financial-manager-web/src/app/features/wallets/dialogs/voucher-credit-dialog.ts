import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../../core/errors/form-errors';
import { fromDateInput, toDateInput } from '../../../core/formatting/dates';
import { MoneyPipe } from '../../../core/formatting/pipes';
import { Sheet, SheetFooter } from '../../../shared/ui/sheet';
import { Spinner } from '../../../shared/ui/states';
import { TransactionsApi } from '../../transactions/transactions.api';
import { Wallet } from '../wallet.model';
import { WalletSelect } from '../wallet-select';
import { WalletsStore } from '../wallets.store';

export interface VoucherCreditData {
  /** Preselected meal-voucher wallet; with none the user picks one. */
  wallet?: Wallet;
  /** true: load a new batch; false: remove vouchers outside a purchase. */
  addition: boolean;
}

/**
 * Loads a batch of meal vouchers (a lot; the server computes its expiry
 * from the wallet's policy) or removes some outside a purchase (lost,
 * miscounted), consumed FIFO like a spend. The input is a count of
 * vouchers, not an amount.
 */
@Component({
  selector: 'app-voucher-credit-dialog',
  imports: [
    MoneyPipe,
    ReactiveFormsModule,
    Sheet,
    SheetFooter,
    Spinner,
    TranslocoPipe,
    WalletSelect,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-sheet
      [title]="(data.addition ? 'addVouchersSheetTitle' : 'removeVouchersSheetTitle') | transloco"
    >
      <form
        id="voucher-credit-form"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="submit()"
        novalidate
      >
        @if (!data.wallet) {
          <div>
            <p class="label">{{ 'voucherWalletLabel' | transloco }}</p>
            <app-wallet-select formControlName="walletId" [types]="['MEAL_VOUCHER']" />
            @if (errors.fields()['wallet']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
        }
        <div class="grid gap-5 sm:grid-cols-2">
          <div>
            <label class="label" for="vc-qty">{{ 'voucherQuantityLabel' | transloco }}</label>
            <input
              id="vc-qty"
              type="number"
              min="1"
              step="1"
              class="input tabular"
              formControlName="quantity"
              [attr.aria-invalid]="!!errors.fields()['quantity'] || null"
            />
            @if (errors.fields()['quantity']; as m) {
              <p class="field-error">{{ m }}</p>
            }
            @if (unitValue(); as unit) {
              <p class="hint">= {{ unit * (values().quantity ?? 0) | money }}</p>
            }
          </div>
          <div>
            <label class="label" for="vc-date">
              {{ (data.addition ? 'voucherLoadedAtLabel' : 'dateAndTimeLabel') | transloco }}
            </label>
            <input id="vc-date" type="date" class="input" formControlName="date" />
          </div>
        </div>
        <div>
          <label class="label" for="vc-reason">{{ 'reasonOptionalLabel' | transloco }}</label>
          <input id="vc-reason" class="input" formControlName="reason" />
        </div>
        @if (errors.message()) {
          <p class="field-error" role="alert">{{ errors.message() }}</p>
        }
      </form>
      <app-sheet-footer>
        <button type="button" class="btn btn-ghost" (click)="ref.close()">
          {{ 'commonCancel' | transloco }}
        </button>
        <button
          type="submit"
          form="voucher-credit-form"
          class="btn"
          [class.btn-primary]="data.addition"
          [class.btn-danger]="!data.addition"
          [disabled]="saving()"
        >
          @if (saving()) {
            <app-spinner />
          }
          {{ (data.addition ? 'addVouchersAction' : 'removeVouchersAction') | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class VoucherCreditDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  protected readonly data = inject<VoucherCreditData>(DIALOG_DATA);
  private readonly api = inject(TransactionsApi);
  private readonly wallets = inject(WalletsStore);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly form = this.fb.group({
    walletId: this.fb.control<string | null>(
      this.data.wallet?.id ??
        (this.wallets.voucherWallets().length === 1 ? this.wallets.voucherWallets()[0].id : null),
    ),
    quantity: this.fb.control<number | null>(1),
    date: [toDateInput(new Date())],
    reason: [''],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });
  protected readonly unitValue = computed(() => {
    const wallet = this.data.wallet ?? this.wallets.byId(this.values().walletId);
    return wallet?.voucher_unit_value_minor ?? null;
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    const quantity = Math.trunc(Number(v.quantity ?? 0));
    const codes: Record<string, string> = {};
    if (!v.walletId) codes['wallet'] = 'selectWalletPlaceholder';
    if (!(quantity > 0)) codes['quantity'] = 'AMOUNT_NOT_POSITIVE';
    if (!this.errors.check(codes)) return;
    this.saving.set(true);
    try {
      await this.api.createVoucherCredit(v.walletId!, {
        quantity: this.data.addition ? quantity : -quantity,
        reason: v.reason.trim() || null,
        occurred_at: (fromDateInput(v.date) ?? new Date()).toISOString(),
      });
      this.ref.close(true);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
