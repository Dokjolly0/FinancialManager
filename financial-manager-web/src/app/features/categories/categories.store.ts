import { HttpClient, httpResource } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api } from '../../core/api/api';
import { Ledger } from '../../core/state/ledger';
import { Direction } from '../transactions/transaction.model';
import { CATEGORY_SORTS, CategorySort, sortCategories } from './category-sort';

/** Which directions a category applies to (plan.md section 11.7). */
export type CategoryScope = 'DEBIT' | 'CREDIT' | 'BOTH';

/** System categories (Casa, Stipendio, ...) plus the user's own. */
export interface Category {
  id: string;
  name: string;
  direction_scope: CategoryScope;
  color?: string | null;
  is_system: boolean;
  sort_order: number;
  /** The user's transactions using it, whole history: "most used" order and the delete warning. */
  usage_count?: number;
  /** A system category the user hid from the pickers; history still shows it. */
  hidden?: boolean;
}

export interface CategoryInput {
  name: string;
  direction_scope: CategoryScope;
  color: string | null;
}

/** Offered for an operation of this direction (section 7.6). */
export const categoryMatches = (category: Category, direction: Direction) =>
  category.direction_scope === 'BOTH' || category.direction_scope === direction;

const SORT_KEY = 'fm.categories.sort';

/**
 * /v1/categories, cached for the page and shared by every picker and list,
 * in the chosen order (remembered in this browser). Reloads on every ledger
 * change, so usage counts stay current.
 */
@Injectable({ providedIn: 'root' })
export class CategoriesStore {
  private readonly http = inject(HttpClient);
  private readonly ledger = inject(Ledger);
  private readonly resource = httpResource<{ categories: Category[] | null }>(() => {
    this.ledger.revision();
    return api('/categories');
  });

  /** A–Z or most used, shared by the picker and the Categories page. */
  readonly sort = signal<CategorySort>(readSort());

  /** Every visible category, hidden ones included (pickers leave those out). */
  readonly categories = computed<Category[]>(() =>
    sortCategories(this.resource.value()?.categories ?? [], this.sort()),
  );
  readonly loading = computed(() => this.resource.isLoading() && !this.resource.hasValue());
  readonly error = computed(() => this.resource.error());
  readonly loaded = computed(() => this.resource.hasValue());
  private readonly byIdMap = computed(
    () => new Map(this.categories().map((category) => [category.id, category])),
  );

  byId(id: string | null | undefined): Category | undefined {
    return id ? this.byIdMap().get(id) : undefined;
  }

  name(id: string | null | undefined): string | null {
    return this.byId(id)?.name ?? null;
  }

  setSort(sort: CategorySort): void {
    this.sort.set(sort);
    try {
      localStorage.setItem(SORT_KEY, sort);
    } catch {
      // Storage blocked: the choice lasts for this page.
    }
  }

  reload(): void {
    this.resource.reload();
  }

  async create(name: string, direction_scope: CategoryScope): Promise<Category> {
    return this.save(null, { name, direction_scope, color: null });
  }

  /** Creates (id null) or updates one of the user's own categories. */
  async save(id: string | null, input: CategoryInput): Promise<Category> {
    const category = await firstValueFrom(
      id
        ? this.http.patch<Category>(api(`/categories/${id}`), input)
        : this.http.post<Category>(api('/categories'), input),
    );
    this.resource.reload();
    return category;
  }

  /**
   * Archives one of the user's own categories; its operations are left
   * without a category, so balances' screens and reports reload too.
   */
  async remove(id: string): Promise<void> {
    await firstValueFrom(this.http.delete(api(`/categories/${id}`)));
    this.ledger.changed();
  }

  /** Hides a system category from the pickers, or shows it again. */
  async setHidden(id: string, hidden: boolean): Promise<void> {
    const url = api(`/categories/${id}/hidden`);
    await firstValueFrom(hidden ? this.http.put(url, null) : this.http.delete(url));
    this.resource.reload();
  }
}

function readSort(): CategorySort {
  try {
    const stored = localStorage.getItem(SORT_KEY);
    return CATEGORY_SORTS.find((sort) => sort === stored) ?? 'alphabetical';
  } catch {
    return 'alphabetical';
  }
}
