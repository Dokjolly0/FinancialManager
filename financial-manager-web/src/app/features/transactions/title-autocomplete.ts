import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import {
  ChangeDetectionStrategy,
  Component,
  forwardRef,
  inject,
  input,
  output,
  signal,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';
import { Repeat } from 'lucide';

import { Icon } from '../../shared/ui/icon';
import { Spinner } from '../../shared/ui/states';
import { CategoriesStore } from '../categories/categories.store';
import { TemplatesApi, TransactionTemplate } from './templates.api';
import { Direction } from './transaction.model';

/**
 * Title field with template suggestions (plan.md sections 7.6, 17.3): after
 * a character, matching templates of the current direction with their
 * category and usage count, debounced. Picking one is reported through
 * `picked`; typing on just leaves a plain title (section 4.4). Arrow keys and
 * Enter work like a native combobox.
 */
@Component({
  selector: 'app-title-autocomplete',
  host: { class: 'block' },
  imports: [CdkConnectedOverlay, CdkOverlayOrigin, Icon, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => TitleAutocomplete), multi: true },
  ],
  template: `
    <div class="relative" cdkOverlayOrigin #origin="cdkOverlayOrigin">
      <input
        class="input pr-10"
        [id]="inputId()"
        role="combobox"
        [attr.aria-controls]="listId"
        autocomplete="off"
        aria-autocomplete="list"
        [attr.aria-expanded]="open()"
        [attr.aria-invalid]="invalid() || null"
        [value]="value()"
        [disabled]="disabled()"
        (input)="onInput($any($event.target).value)"
        (keydown)="onKey($event)"
        (blur)="onBlur()"
      />
      @if (searching()) {
        <app-spinner class="absolute right-3.5 top-1/2 -translate-y-1/2 text-fg-muted" />
      }
    </div>
    <ng-template
      cdkConnectedOverlay
      [cdkConnectedOverlayOrigin]="origin"
      [cdkConnectedOverlayOpen]="open()"
      [cdkConnectedOverlayPositions]="positions"
      [cdkConnectedOverlayWidth]="origin.elementRef.nativeElement.offsetWidth"
    >
      <ul
        class="max-h-64 w-full overflow-y-auto rounded-xl border border-border bg-surface p-1.5 shadow-pop"
        role="listbox"
        [id]="listId"
      >
        @for (template of suggestions(); track template.id; let i = $index) {
          <li>
            <button
              type="button"
              role="option"
              class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left"
              [class.bg-surface-2]="i === active()"
              [attr.aria-selected]="i === active()"
              (mousedown)="$event.preventDefault()"
              (click)="pick(template)"
            >
              <span class="min-w-0 flex-1">
                <span class="block truncate text-sm font-medium text-fg">{{ template.title }}</span>
                @if (categories.name(template.default_category_id); as category) {
                  <span class="block truncate text-xs text-fg-muted">{{ category }}</span>
                }
              </span>
              <span
                class="badge bg-surface-2 text-fg-muted"
                [title]="'webTemplateUsage' | transloco: { count: template.usage_count }"
              >
                <app-icon [icon]="Repeat" [size]="11" /> {{ template.usage_count }}
              </span>
            </button>
          </li>
        }
      </ul>
    </ng-template>
  `,
})
export class TitleAutocomplete implements ControlValueAccessor {
  readonly direction = input.required<Direction>();
  readonly inputId = input<string>();
  readonly invalid = input(false);
  readonly picked = output<TransactionTemplate>();

  private readonly api = inject(TemplatesApi);
  protected readonly categories = inject(CategoriesStore);
  protected readonly Repeat = Repeat;
  protected readonly positions: ConnectedPosition[] = [
    { originX: 'start', originY: 'bottom', overlayX: 'start', overlayY: 'top', offsetY: 6 },
  ];

  private static nextId = 0;
  protected readonly listId = `title-suggestions-${TitleAutocomplete.nextId++}`;
  protected readonly value = signal('');
  protected readonly disabled = signal(false);
  protected readonly suggestions = signal<TransactionTemplate[]>([]);
  protected readonly searching = signal(false);
  protected readonly open = signal(false);
  protected readonly active = signal(0);
  private timer: ReturnType<typeof setTimeout> | undefined;
  private request = 0;
  private onChange: (value: string) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected onInput(value: string): void {
    this.value.set(value);
    this.onChange(value);
    clearTimeout(this.timer);
    if (!value.trim()) {
      this.close();
      return;
    }
    this.timer = setTimeout(() => void this.search(value), 300);
  }

  private async search(query: string): Promise<void> {
    const request = ++this.request;
    this.searching.set(true);
    try {
      const results = await this.api.search(this.direction(), query);
      if (request !== this.request) return;
      this.suggestions.set(results);
      this.active.set(0);
      this.open.set(results.length > 0);
    } catch {
      if (request === this.request) this.close();
    } finally {
      if (request === this.request) this.searching.set(false);
    }
  }

  protected onKey(event: KeyboardEvent): void {
    if (!this.open()) return;
    const count = this.suggestions().length;
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      this.active.update((i) => (i + 1) % count);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      this.active.update((i) => (i - 1 + count) % count);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      this.pick(this.suggestions()[this.active()]);
    } else if (event.key === 'Escape') {
      this.close();
    }
  }

  protected onBlur(): void {
    this.onTouched();
    setTimeout(() => this.close(), 120);
  }

  protected pick(template: TransactionTemplate): void {
    this.value.set(template.title);
    this.onChange(template.title);
    this.picked.emit(template);
    this.close();
  }

  private close(): void {
    this.request++;
    this.searching.set(false);
    this.open.set(false);
    this.suggestions.set([]);
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
