import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { FormErrors } from '../../../core/errors/form-errors';
import { fromDateTimeInput, toDateTimeInput } from '../../../core/formatting/dates';
import { MoneyPipe } from '../../../core/formatting/pipes';
import { AmountInput } from '../../../shared/ui/form-controls';
import { Sheet, SheetFooter } from '../../../shared/ui/sheet';
import { Spinner } from '../../../shared/ui/states';
import { ImageField } from '../../media/image-field';
import { Transaction } from '../../transactions/transaction.model';
import { TransactionsApi } from '../../transactions/transactions.api';
import { WalletSelect } from '../wallet-select';
import { WalletsStore } from '../wallets.store';

/** Editing: the voucher-wallet leg and, if the expense had one, the shortfall leg. */
export interface VoucherExpenseData {
  voucherTransaction?: Transaction;
  otherTransaction?: Transaction | null;
}

/**
 * A purchase paid partly or fully with meal vouchers: the real total, how
 * many vouchers (with the minimum that covers it as a hint), and, only when
 * the vouchers fall short, the wallet paying the difference. Also an image,
 * like the operation form; no category or template, it's a focused flow.
 */
@Component({
  selector: 'app-voucher-expense-dialog',
  imports: [
    AmountInput,
    ImageField,
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
      [title]="(editing ? 'editVoucherExpenseSheetTitle' : 'voucherExpenseSheetTitle') | transloco"
    >
      <form
        id="voucher-expense-form"
        class="space-y-5"
        [formGroup]="form"
        (ngSubmit)="submit()"
        novalidate
      >
        @if (!editing) {
          <div>
            <p class="label">{{ 'voucherWalletLabel' | transloco }}</p>
            <app-wallet-select formControlName="voucherWalletId" [types]="['MEAL_VOUCHER']" />
            @if (errors.fields()['voucher_wallet_id']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
        }
        <div>
          <label class="label" for="ve-title">{{ 'titleFieldLabel' | transloco }}</label>
          <input
            id="ve-title"
            class="input"
            formControlName="title"
            [attr.aria-invalid]="!!errors.fields()['title'] || null"
          />
          @if (errors.fields()['title']; as m) {
            <p class="field-error">{{ m }}</p>
          }
        </div>
        <div class="grid gap-5 sm:grid-cols-2">
          <div>
            <label class="label" for="ve-total">{{ 'voucherTotalExpenseLabel' | transloco }}</label>
            <app-amount-input
              inputId="ve-total"
              formControlName="total"
              [invalid]="!!errors.fields()['total_expense_minor']"
            />
            @if (errors.fields()['total_expense_minor']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
          <div>
            <label class="label" for="ve-qty">{{ 'voucherQuantityLabel' | transloco }}</label>
            <input
              id="ve-qty"
              type="number"
              min="1"
              step="1"
              class="input tabular"
              formControlName="quantity"
              [attr.aria-invalid]="!!errors.fields()['voucher_quantity'] || null"
            />
            @if (suggested(); as count) {
              <p class="hint">{{ 'voucherSuggestedQuantityHelper' | transloco: { count } }}</p>
            }
            @if (errors.fields()['voucher_quantity']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
        </div>
        @if (shortfall() > 0) {
          <div class="rounded-xl border border-warning/40 bg-warning/5 p-4">
            <p class="mb-3 text-sm font-medium text-fg">
              {{ 'voucherShortfallLabel' | transloco: { amount: (shortfall() | money) } }}
            </p>
            <p class="label">{{ 'voucherOtherWalletLabel' | transloco }}</p>
            <app-wallet-select
              formControlName="otherWalletId"
              [types]="['BANK', 'CASH', 'OTHER']"
            />
            @if (errors.fields()['other_wallet_id']; as m) {
              <p class="field-error">{{ m }}</p>
            }
          </div>
        }
        <div>
          <label class="label" for="ve-date">{{ 'dateAndTimeLabel' | transloco }}</label>
          <input id="ve-date" type="datetime-local" class="input" formControlName="occurredAt" />
        </div>
        <div>
          <label class="label" for="ve-desc">{{ 'descriptionOptionalLabel' | transloco }}</label>
          <textarea id="ve-desc" class="input" rows="2" formControlName="description"></textarea>
        </div>
        <div>
          <p class="label">{{ 'webImageLabel' | transloco }}</p>
          <app-image-field formControlName="mediaId" kind="transaction" />
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
          form="voucher-expense-form"
          class="btn btn-primary"
          [disabled]="saving()"
        >
          @if (saving()) {
            <app-spinner />
          }
          {{ 'saveVoucherExpenseAction' | transloco }}
        </button>
      </app-sheet-footer>
    </app-sheet>
  `,
})
export class VoucherExpenseDialog {
  protected readonly ref = inject<DialogRef<boolean>>(DialogRef);
  private readonly data = inject<VoucherExpenseData>(DIALOG_DATA, { optional: true }) ?? {};
  private readonly api = inject(TransactionsApi);
  private readonly wallets = inject(WalletsStore);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly editing = !!this.data.voucherTransaction;
  private readonly voucherTx = this.data.voucherTransaction;
  private readonly otherTx = this.data.otherTransaction ?? null;

  protected readonly form = this.fb.group({
    voucherWalletId: this.fb.control<string | null>(
      this.voucherTx?.wallet_id ??
        (this.wallets.voucherWallets().length === 1 ? this.wallets.voucherWallets()[0].id : null),
    ),
    otherWalletId: this.fb.control<string | null>(this.otherTx?.wallet_id ?? null),
    title: [this.voucherTx?.title ?? ''],
    total: this.fb.control<number | null>(
      this.voucherTx ? this.voucherTx.amount_minor + (this.otherTx?.amount_minor ?? 0) : null,
    ),
    quantity: this.fb.control<number | null>(this.initialQuantity()),
    occurredAt: [
      toDateTimeInput(this.voucherTx ? new Date(this.voucherTx.occurred_at) : new Date()),
    ],
    description: [this.voucherTx?.description ?? ''],
    mediaId: this.fb.control<string | null>(this.voucherTx?.media_id ?? null),
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();

  private readonly unit = computed(
    () => this.wallets.byId(this.values().voucherWalletId)?.voucher_unit_value_minor ?? null,
  );
  private readonly quantity = computed(() => Math.trunc(Number(this.values().quantity ?? 0)));
  /** What the vouchers don't cover; the other wallet pays it. */
  protected readonly shortfall = computed(() => {
    const unit = this.unit();
    if (!unit) return 0;
    return Math.max(0, (this.values().total ?? 0) - this.quantity() * unit);
  });
  /** Fewest vouchers covering the total. */
  protected readonly suggested = computed(() => {
    const unit = this.unit();
    const total = this.values().total ?? 0;
    return unit && total > 0 ? Math.ceil(total / unit) : null;
  });

  private initialQuantity(): number {
    const unit = this.data.voucherTransaction
      ? this.wallets.byId(this.data.voucherTransaction.wallet_id)?.voucher_unit_value_minor
      : null;
    return this.data.voucherTransaction && unit
      ? Math.floor(this.data.voucherTransaction.amount_minor / unit)
      : 1;
  }

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    const shortfall = this.shortfall();
    const codes: Record<string, string> = {};
    if (v.total === null || v.total <= 0) codes['total_expense_minor'] = 'AMOUNT_NOT_POSITIVE';
    if (!(this.quantity() > 0)) codes['voucher_quantity'] = 'AMOUNT_NOT_POSITIVE';
    if (!v.title.trim()) codes['title'] = 'REQUIRED_FIELD';
    if (!v.voucherWalletId) codes['voucher_wallet_id'] = 'selectWalletPlaceholder';
    if (shortfall > 0 && !v.otherWalletId)
      codes['other_wallet_id'] = 'voucherOtherWalletRequiredError';
    if (!this.errors.check(codes)) return;

    const body = {
      voucher_quantity: this.quantity(),
      total_expense_minor: v.total!,
      other_wallet_id: shortfall > 0 ? v.otherWalletId : null,
      title: v.title.trim(),
      description: v.description.trim() || null,
      media_id: v.mediaId,
      occurred_at: (fromDateTimeInput(v.occurredAt) ?? new Date()).toISOString(),
    };
    this.saving.set(true);
    try {
      if (this.voucherTx) {
        await this.api.updateVoucherExpense(this.voucherTx.id, {
          ...body,
          version: this.voucherTx.version,
        });
      } else {
        await this.api.createVoucherExpense({ ...body, voucher_wallet_id: v.voucherWalletId! });
      }
      this.ref.close(true);
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }
}
