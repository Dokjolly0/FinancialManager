import { ChangeDetectionStrategy, Component, forwardRef, input, signal } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';
import { Eye, EyeOff } from 'lucide';

import { Icon } from './icon';

/** Password field with show/hide (the app's PasswordField). */
@Component({
  selector: 'app-password-input',
  host: { class: 'block' },
  imports: [Icon, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => PasswordInput), multi: true },
  ],
  template: `
    <div class="relative">
      <input
        class="input pr-11"
        [id]="inputId()"
        [type]="visible() ? 'text' : 'password'"
        [attr.autocomplete]="autocomplete()"
        [value]="value()"
        [disabled]="disabled()"
        [attr.aria-invalid]="invalid() || null"
        (input)="onInput($any($event.target).value)"
        (blur)="onTouched()"
      />
      <button
        type="button"
        class="absolute inset-y-0 right-1 my-auto grid h-9 w-9 place-items-center rounded-lg text-fg-muted hover:text-fg"
        [attr.aria-label]="(visible() ? 'webHidePassword' : 'webShowPassword') | transloco"
        (click)="visible.set(!visible())"
      >
        <app-icon [icon]="visible() ? EyeOff : Eye" [size]="18" />
      </button>
    </div>
  `,
})
export class PasswordInput implements ControlValueAccessor {
  readonly inputId = input<string>();
  readonly autocomplete = input('current-password');
  readonly invalid = input(false);

  protected readonly visible = signal(false);
  protected readonly value = signal('');
  protected readonly disabled = signal(false);
  protected readonly Eye = Eye;
  protected readonly EyeOff = EyeOff;
  private onChange: (value: string) => void = () => undefined;
  protected onTouched: () => void = () => undefined;

  protected onInput(value: string): void {
    this.value.set(value);
    this.onChange(value);
  }

  writeValue(value: string | null): void {
    this.value.set(value ?? '');
  }
  registerOnChange(fn: (value: string) => void): void {
    this.onChange = fn;
  }
  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }
  setDisabledState(disabled: boolean): void {
    this.disabled.set(disabled);
  }
}
