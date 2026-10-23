import {
  ChangeDetectionStrategy,
  Component,
  computed,
  forwardRef,
  inject,
  input,
  signal,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';

import { MoneyPipe } from '../../core/formatting/pipes';
import { WalletType } from './wallet.model';
import { WalletBadge } from './wallet-badge';
import { WalletsStore } from './wallets.store';

/**
 * Picks one wallet among cards showing icon, name and balance (the app's
 * WalletPickerSheet), optionally limited by type or excluding one wallet.
 * The value is the wallet id.
 */
@Component({
  selector: 'app-wallet-select',
  imports: [MoneyPipe, TranslocoPipe, WalletBadge],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => WalletSelect), multi: true },
  ],
  template: `
    @if (choices().length === 0) {
      <p class="rounded-xl border border-dashed border-border px-4 py-3 text-sm text-fg-muted">
        {{ 'selectWalletPlaceholder' | transloco }}
      </p>
    }
    <div class="grid gap-2 sm:grid-cols-2" role="radiogroup" [attr.aria-label]="label()">
      @for (wallet of choices(); track wallet.id) {
        <button
          type="button"
          role="radio"
          class="flex items-center gap-3 rounded-xl border px-3 py-2.5 text-left transition-colors disabled:opacity-50"
          [class]="
            value() === wallet.id
              ? 'border-primary bg-primary-soft ring-1 ring-primary'
              : 'border-border bg-surface hover:bg-surface-2'
          "
          [attr.aria-checked]="value() === wallet.id"
          [disabled]="disabled()"
          (click)="select(wallet.id)"
        >
          <app-wallet-badge [icon]="wallet.icon" [color]="wallet.color" [size]="32" />
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-medium text-fg">{{ wallet.name }}</span>
            <span class="tabular block text-xs text-fg-muted">{{
              wallet.current_balance_minor | money: wallet.currency
            }}</span>
          </span>
        </button>
      }
    </div>
  `,
})
export class WalletSelect implements ControlValueAccessor {
  readonly label = input<string>();
  readonly types = input<WalletType[] | null>(null);
  readonly exclude = input<string | null>(null);

  private readonly store = inject(WalletsStore);
  protected readonly value = signal<string | null>(null);
  protected readonly disabled = signal(false);
  private onChange: (value: string | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected readonly choices = computed(() =>
    this.store
      .wallets()
      .filter((wallet) => !this.types() || this.types()!.includes(wallet.type))
      .filter((wallet) => wallet.id !== this.exclude()),
  );

  protected select(id: string): void {
    this.value.set(id);
    this.onChange(id);
    this.onTouched();
  }

  writeValue(value: string | null): void {
    this.value.set(value);
  }
  registerOnChange(fn: (value: string | null) => void): void {
    this.onChange = fn;
  }
  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }
  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
