import {
  ChangeDetectionStrategy,
  Component,
  forwardRef,
  inject,
  input,
  signal,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';
import { ImagePlus, X } from 'lucide';

import { Icon } from '../../shared/ui/icon';
import { MediaSrc } from '../../shared/ui/media-src';
import { Overlay } from '../../shared/ui/overlay';
import type { MediaAsset, MediaKind } from './media.api';

/** An optional image of a form; the value is the media id. Opens the image picker. */
@Component({
  selector: 'app-image-field',
  host: { class: 'block' },
  imports: [Icon, MediaSrc, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => ImageField), multi: true },
  ],
  template: `
    <div class="flex items-center gap-4 rounded-xl border border-border bg-surface p-3">
      @if (value()) {
        <img
          [appMediaSrc]="value()"
          alt=""
          class="h-16 w-16 rounded-xl bg-surface-2 object-cover"
        />
      } @else {
        <span class="grid h-16 w-16 place-items-center rounded-xl bg-surface-2 text-fg-muted">
          <app-icon [icon]="ImagePlus" [size]="24" />
        </span>
      }
      <span class="flex-1 text-sm text-fg-muted">
        {{ (value() ? 'imageSelectedLabel' : 'noImageSelectedLabel') | transloco }}
      </span>
      @if (value()) {
        <button
          type="button"
          class="btn btn-ghost btn-icon btn-sm"
          [attr.aria-label]="'webRemoveImage' | transloco"
          [disabled]="disabled()"
          (click)="set(null)"
        >
          <app-icon [icon]="X" [size]="16" />
        </button>
      }
      <button
        type="button"
        class="btn btn-outline btn-sm"
        [disabled]="disabled()"
        (click)="choose()"
      >
        {{ (value() ? 'webChangeImage' : 'webChooseImage') | transloco }}
      </button>
    </div>
  `,
})
export class ImageField implements ControlValueAccessor {
  readonly kind = input<MediaKind>('transaction');

  private readonly overlay = inject(Overlay);
  protected readonly value = signal<string | null>(null);
  protected readonly disabled = signal(false);
  protected readonly ImagePlus = ImagePlus;
  protected readonly X = X;
  private onChange: (value: string | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected async choose(): Promise<void> {
    const { MediaPickerDialog } = await import('./media-picker-dialog');
    const asset = await this.overlay.result<MediaAsset, MediaKind>(MediaPickerDialog, {
      data: this.kind(),
      wide: true,
    });
    if (asset) this.set(asset.id);
  }

  protected set(id: string | null): void {
    this.value.set(id);
    this.onChange(id);
    this.onTouched();
  }

  writeValue(value: string | null): void {
    this.value.set(value ?? null);
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
