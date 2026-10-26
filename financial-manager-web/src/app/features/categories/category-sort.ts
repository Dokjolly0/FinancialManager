import type { Category } from './categories.store';

/** How category lists are ordered (plan.md section 7.6), the app's CategorySort. */
export type CategorySort = 'alphabetical' | 'mostUsed';

export const CATEGORY_SORTS: CategorySort[] = ['alphabetical', 'mostUsed'];

/**
 * Alphabetical (case-insensitive, the system "Altro" catch-all last) or
 * most used first (usage_count, ties alphabetical): the app's
 * sortCategories, so both clients list categories the same way.
 */
export function sortCategories(categories: readonly Category[], sort: CategorySort): Category[] {
  const alphabetical = (a: Category, b: Category) =>
    Number(isCatchAll(a)) - Number(isCatchAll(b)) ||
    a.name.toLowerCase().localeCompare(b.name.toLowerCase()) ||
    SCOPE_ORDER[a.direction_scope] - SCOPE_ORDER[b.direction_scope];
  return [...categories].sort((a, b) =>
    sort === 'mostUsed'
      ? (b.usage_count ?? 0) - (a.usage_count ?? 0) || alphabetical(a, b)
      : alphabetical(a, b),
  );
}

const SCOPE_ORDER = { DEBIT: 0, CREDIT: 1, BOTH: 2 } as const;

const isCatchAll = (category: Category) =>
  category.is_system && category.name.toLowerCase() === 'altro';
