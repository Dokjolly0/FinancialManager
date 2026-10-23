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

import { LocaleService } from '../../core/formatting/locale.service';
import { minorToInput, parseMinorUnits } from '../../core/formatting/money';

export interface SegmentOption<T> {
  value: T;
  label: string;
}

/** A row of mutually exclusive options (the app's SegmentedButton). */
@Component({
  selector: 'app-segmented',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => Segmented), multi: true },
  ],
  template: `
    <div
      class="inline-flex w-full rounded-xl bg-surface-2 p-1"
      [class.w-auto]="!stretch()"
      role="radiogroup"
      [attr.aria-label]="label()"
    >
      @for (option of options(); track option.value) {
        <button
          type="button"
          role="radio"
          class="h-9 flex-1 rounded-lg px-3 text-sm font-medium transition-all"
          [class]="
            value() === option.value
              ? 'bg-surface text-fg shadow-sm ' + (activeClass(option.value) ?? '')
              : 'text-fg-muted hover:text-fg'
          "
          [attr.aria-checked]="value() === option.value"
          [disabled]="disabled()"
          (click)="select(option.value)"
        >
          {{ option.label }}
        </button>
      }
    </div>
  `,
})
export class Segmented<T> implements ControlValueAccessor {
  readonly options = input.required<SegmentOption<T>[]>();
  readonly label = input<string>();
  readonly stretch = input(true);
  /** Extra classes for the selected option, e.g. credit/debit colours. */
  readonly activeClasses = input<Partial<Record<string, string>>>({});

  protected readonly value = signal<T | null>(null);
  protected readonly disabled = signal(false);
  private onChange: (value: T) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected activeClass(value: T): string | undefined {
    return this.activeClasses()[String(value)];
  }

  protected select(value: T): void {
    this.value.set(value);
    this.onChange(value);
    this.onTouched();
  }

  writeValue(value: T): void {
    this.value.set(value);
  }
  registerOnChange(fn: (value: T) => void): void {
    this.onChange = fn;
  }
  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }
  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}

/** On/off switch with label and description (the app's SwitchListTile). */
@Component({
  selector: 'app-switch',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => Switch), multi: true }],
  template: `
    <button
      type="button"
      role="switch"
      class="flex w-full cursor-pointer items-start gap-4 rounded-lg py-1 text-left disabled:cursor-not-allowed disabled:opacity-60"
      [attr.aria-checked]="checked()"
      [disabled]="disabled()"
      (click)="toggle()"
    >
      <span class="min-w-0 flex-1">
        <span class="block text-sm font-medium text-fg">{{ label() }}</span>
        @if (description()) {
          <span class="mt-0.5 block text-xs leading-relaxed text-fg-muted">{{
            description()
          }}</span>
        }
      </span>
      <span
        class="relative mt-0.5 inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors"
        [class]="checked() ? 'bg-primary' : 'bg-border'"
        aria-hidden="true"
      >
        <span
          class="inline-block h-5 w-5 rounded-full bg-white shadow transition-transform"
          [class]="checked() ? 'translate-x-5.5' : 'translate-x-0.5'"
        ></span>
      </span>
    </button>
  `,
})
export class Switch implements ControlValueAccessor {
  readonly label = input.required<string>();
  readonly description = input<string>();

  protected readonly checked = signal(false);
  protected readonly disabled = signal(false);
  private onChange: (value: boolean) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected toggle(): void {
    this.checked.update((value) => !value);
    this.onChange(this.checked());
    this.onTouched();
  }

  writeValue(value: boolean): void {
    this.checked.set(!!value);
  }
  registerOnChange(fn: (value: boolean) => void): void {
    this.onChange = fn;
  }
  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }
  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}

/**
 * Amount field whose value is integer minor units (or null while the text
 * isn't a valid amount), the app's AmountField. The text is kept as typed;
 * only blur reformats it.
 */
@Component({
  selector: 'app-amount-input',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => AmountInput), multi: true },
  ],
  template: `
    <div class="relative">
      <span
        class="pointer-events-none absolute inset-y-0 left-3.5 flex items-center text-sm font-medium text-fg-muted"
        >{{ symbol() }}</span
      >
      <input
        class="input tabular pl-9"
        [class.h-14]="large()"
        [class.text-2xl]="large()"
        [class.font-semibold]="large()"
        [id]="inputId()"
        inputmode="decimal"
        autocomplete="off"
        [placeholder]="placeholder()"
        [value]="text()"
        [disabled]="disabled()"
        [attr.aria-invalid]="invalid() || null"
        (input)="onInput($any($event.target).value)"
        (blur)="onBlur()"
      />
    </div>
  `,
})
export class AmountInput implements ControlValueAccessor {
  readonly inputId = input<string>();
  readonly currency = input('EUR');
  readonly large = input(false);
  readonly invalid = input(false);

  private readonly locale = inject(LocaleService);
  protected readonly text = signal('');
  protected readonly disabled = signal(false);
  protected readonly symbol = computed(
    () =>
      new Intl.NumberFormat(this.locale.intl(), { style: 'currency', currency: this.currency() })
        .formatToParts(0)
        .find((part) => part.type === 'currency')?.value ?? '€',
  );
  protected readonly placeholder = computed(() => minorToInput(0, this.locale.intl()));

  private onChange: (value: number | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected onInput(value: string): void {
    this.text.set(value);
    this.onChange(parseMinorUnits(value));
  }

  protected onBlur(): void {
    const minor = parseMinorUnits(this.text());
    if (minor !== null) this.text.set(minorToInput(minor, this.locale.intl()));
    this.onTouched();
  }

  writeValue(value: number | null): void {
    this.text.set(
      value === null || value === undefined ? '' : minorToInput(value, this.locale.intl()),
    );
  }
  registerOnChange(fn: (value: number | null) => void): void {
    this.onChange = fn;
  }
  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }
  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
