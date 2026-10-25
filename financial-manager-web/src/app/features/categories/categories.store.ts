import { HttpClient, httpResource } from '@angular/common/http';
import { Injectable, computed, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api } from '../../core/api/api';
import { Direction } from '../transactions/transaction.model';

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
}

/** Offered for an operation of this direction (section 7.6). */
export const categoryMatches = (category: Category, direction: Direction) =>
  category.direction_scope === 'BOTH' || category.direction_scope === direction;

/** GET/POST /v1/categories, cached for the page and shared by every picker and list. */
@Injectable({ providedIn: 'root' })
export class CategoriesStore {
  private readonly http = inject(HttpClient);
  private readonly resource = httpResource<{ categories: Category[] | null }>(() =>
    api('/categories'),
  );

  readonly categories = computed<Category[]>(() =>
    [...(this.resource.value()?.categories ?? [])].sort((a, b) => a.sort_order - b.sort_order),
  );
  private readonly byIdMap = computed(
    () => new Map(this.categories().map((category) => [category.id, category])),
  );

  byId(id: string | null | undefined): Category | undefined {
    return id ? this.byIdMap().get(id) : undefined;
  }

  name(id: string | null | undefined): string | null {
    return this.byId(id)?.name ?? null;
  }

  async create(name: string, direction_scope: CategoryScope): Promise<Category> {
    const category = await firstValueFrom(
      this.http.post<Category>(api('/categories'), { name, direction_scope, color: null }),
    );
    this.resource.reload();
    return category;
  }
}
