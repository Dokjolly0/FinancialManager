import { CdkConnectedOverlay, CdkOverlayOrigin, ConnectedPosition } from '@angular/cdk/overlay';
import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  computed,
  forwardRef,
  inject,
  input,
  signal,
  viewChild,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { TranslocoPipe } from '@jsverse/transloco';
import { Ban, Check, ChevronsUpDown, EllipsisVertical, Plus, Search } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { Icon } from '../../shared/ui/icon';
import { Spinner } from '../../shared/ui/states';
import { Direction } from '../transactions/transaction.model';
import { CategoriesStore, Category, categoryMatches } from './categories.store';
import { CategoryActions } from './category-actions';
import { CategorySortToggle } from './category-sort-toggle';

/**
 * Category picker (the app's CategoryPickerSheet) as a searchable dropdown:
 * categories valid for the direction (all of them without one) in the
 * shared A–Z / most used order, hidden ones left out, "no category", and
 * creating the typed name as a new category for that direction. Each row's
 * menu button opens the category's actions. The value is the category id.
 */
@Component({
  selector: 'app-category-select',
  host: { class: 'block' },
  imports: [
    CategorySortToggle,
    CdkConnectedOverlay,
    CdkOverlayOrigin,
    Icon,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    { provide: NG_VALUE_ACCESSOR, useExisting: forwardRef(() => CategorySelect), multi: true },
  ],
  template: `
    <button
      type="button"
      cdkOverlayOrigin
      #origin="cdkOverlayOrigin"
      class="input flex items-center gap-2 text-left"
      [id]="inputId()"
      [attr.aria-expanded]="open()"
      aria-haspopup="listbox"
      [disabled]="disabled()"
      (click)="toggle()"
    >
      @if (selected(); as category) {
        <span
          class="h-2.5 w-2.5 shrink-0 rounded-full"
          [style.background-color]="category.color || 'var(--c-primary)'"
        ></span>
        <span class="flex-1 truncate">{{ category.name }}</span>
      } @else {
        <span class="flex-1 truncate text-fg-muted">{{ 'noCategoryLabel' | transloco }}</span>
      }
      <app-icon [icon]="icons.ChevronsUpDown" [size]="16" class="text-fg-muted" />
    </button>

    <ng-template
      cdkConnectedOverlay
      [cdkConnectedOverlayOrigin]="origin"
      [cdkConnectedOverlayOpen]="open()"
      [cdkConnectedOverlayPositions]="positions"
      [cdkConnectedOverlayWidth]="origin.elementRef.nativeElement.offsetWidth"
      [cdkConnectedOverlayHasBackdrop]="true"
      cdkConnectedOverlayBackdropClass="cdk-overlay-transparent-backdrop"
      (backdropClick)="open.set(false)"
      (detach)="open.set(false)"
      (attach)="focusSearch()"
      (overlayKeydown)="$event.key === 'Escape' && open.set(false)"
    >
      <div
        class="w-full overflow-hidden rounded-xl border border-border bg-surface shadow-pop animate-fade-in"
      >
        <label class="flex items-center gap-2 border-b border-border px-3">
          <app-icon [icon]="icons.Search" [size]="16" class="text-fg-muted" />
          <input
            #search
            class="h-11 flex-1 bg-transparent text-sm text-fg outline-none placeholder:text-fg-muted"
            [placeholder]="'categorySearchHint' | transloco"
            [value]="query()"
            (input)="query.set($any($event.target).value)"
            (keydown.enter)="$event.preventDefault(); enter()"
          />
        </label>
        <app-category-sort-toggle class="border-b border-border px-1.5 py-1.5" />
        <ul class="max-h-72 overflow-y-auto p-1.5" role="listbox">
          @if (!query().trim()) {
            <li>
              <button
                type="button"
                role="option"
                class="option"
                [attr.aria-selected]="!value()"
                (click)="choose(null)"
              >
                <app-icon [icon]="icons.Ban" [size]="16" class="text-fg-muted" />
                <span class="flex-1">{{ 'noCategoryLabel' | transloco }}</span>
                @if (!value()) {
                  <app-icon [icon]="icons.Check" [size]="16" class="text-primary" />
                }
              </button>
            </li>
          }
          @for (category of visible(); track category.id) {
            <li class="group flex items-center">
              <button
                type="button"
                role="option"
                class="option"
                [attr.aria-selected]="value() === category.id"
                (click)="choose(category)"
              >
                <span
                  class="h-2.5 w-2.5 shrink-0 rounded-full"
                  [style.background-color]="category.color || 'var(--c-primary)'"
                ></span>
                <span class="flex-1 truncate">{{ category.name }}</span>
                @if (value() === category.id) {
                  <app-icon [icon]="icons.Check" [size]="16" class="text-primary" />
                }
              </button>
              <button
                type="button"
                class="btn btn-ghost btn-icon btn-sm shrink-0 text-fg-muted opacity-0 focus-visible:opacity-100 group-hover:opacity-100 max-sm:opacity-100"
                [attr.aria-label]="'editCategoryAction' | transloco"
                (click)="openActions(category)"
              >
                <app-icon [icon]="icons.EllipsisVertical" [size]="16" />
              </button>
            </li>
          } @empty {
            @if (query().trim()) {
              <li class="px-3 py-3 text-sm text-fg-muted">
                {{ 'categorySearchNoResults' | transloco }}
              </li>
            }
          }
          @if (allowCreate() && query().trim() && !exactMatch()) {
            <li class="mt-1 border-t border-border pt-1">
              <button
                type="button"
                class="option text-primary"
                [disabled]="creating()"
                (click)="create()"
              >
                @if (creating()) {
                  <app-spinner />
                } @else {
                  <app-icon [icon]="icons.Plus" [size]="16" />
                }
                <span class="flex-1 truncate"
                  >{{ 'newCategoryAction' | transloco }}: “{{ query().trim() }}”</span
                >
              </button>
            </li>
          }
          @if (createError()) {
            <li class="px-3 py-2 text-xs text-debit">{{ createError() }}</li>
          }
        </ul>
      </div>
    </ng-template>
  `,
  styles: `
    .option {
      display: flex;
      width: 100%;
      align-items: center;
      gap: 0.6rem;
      border-radius: 0.5rem;
      padding: 0.55rem 0.75rem;
      text-align: left;
      font-size: 0.875rem;
      color: var(--c-fg);
    }
    .option:hover,
    .option:focus-visible {
      background: var(--c-surface-2);
      outline: none;
    }
  `,
})
export class CategorySelect implements ControlValueAccessor {
  /** Only categories for this direction; null shows them all (history filters). */
  readonly direction = input<Direction | null>(null);
  readonly allowCreate = input(true);
  readonly inputId = input<string>();

  private readonly store = inject(CategoriesStore);
  private readonly errors = inject(ErrorText);
  private readonly actions = inject(CategoryActions);

  protected readonly icons = { Ban, Check, ChevronsUpDown, EllipsisVertical, Plus, Search };
  protected readonly positions: ConnectedPosition[] = [
    { originX: 'start', originY: 'bottom', overlayX: 'start', overlayY: 'top', offsetY: 6 },
    { originX: 'start', originY: 'top', overlayX: 'start', overlayY: 'bottom', offsetY: -6 },
  ];
  protected readonly open = signal(false);
  protected readonly query = signal('');
  protected readonly value = signal<string | null>(null);
  protected readonly disabled = signal(false);
  protected readonly creating = signal(false);
  protected readonly createError = signal<string | null>(null);
  private readonly search = viewChild<ElementRef<HTMLInputElement>>('search');
  private onChange: (value: string | null) => void = () => undefined;
  private onTouched: () => void = () => undefined;

  protected readonly selected = computed(() => this.store.byId(this.value()));
  protected readonly visible = computed(() => {
    const q = this.query().trim().toLowerCase();
    const direction = this.direction();
    return this.store
      .categories()
      .filter((c) => !c.hidden && (!direction || categoryMatches(c, direction)))
      .filter((c) => c.name.toLowerCase().includes(q));
  });
  protected readonly exactMatch = computed(() => {
    const q = this.query().trim().toLowerCase();
    return this.visible().some((c) => c.name.toLowerCase() === q);
  });

  protected focusSearch(): void {
    setTimeout(() => this.search()?.nativeElement.focus());
  }

  protected toggle(): void {
    this.query.set('');
    this.createError.set(null);
    this.open.update((open) => !open);
  }

  protected enter(): void {
    const first = this.visible()[0];
    if (first) this.choose(first);
    else if (this.allowCreate() && this.query().trim()) void this.create();
  }

  /** Closes the dropdown, then shows the category's actions. */
  protected openActions(category: Category): void {
    this.open.set(false);
    void this.actions.open(category);
  }

  protected choose(category: Category | null): void {
    this.value.set(category?.id ?? null);
    this.onChange(category?.id ?? null);
    this.onTouched();
    this.open.set(false);
  }

  /** New categories take the operation's direction (debit when unknown), like the app. */
  protected async create(): Promise<void> {
    this.creating.set(true);
    this.createError.set(null);
    try {
      const category = await this.store.create(
        this.query().trim(),
        this.direction() === 'CREDIT' ? 'CREDIT' : 'DEBIT',
      );
      this.choose(category);
    } catch (error) {
      const message = this.errors.message(error);
      this.createError.set(message);
    } finally {
      this.creating.set(false);
    }
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
