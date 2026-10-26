import type { Category } from './categories.store';
import { sortCategories } from './category-sort';

function category(name: string, usage_count = 0, is_system = false): Category {
  return { id: name, name, direction_scope: 'DEBIT', is_system, sort_order: 0, usage_count };
}

const names = (categories: Category[]) => categories.map((c) => c.name);

describe('sortCategories', () => {
  const categories = [
    category('Altro', 9, true),
    category('zeta', 1),
    category('Casa', 5, true),
    category('alimentari', 5, true),
    category('Benzina', 0),
  ];

  it('is alphabetical, case-insensitive, with the system "Altro" last', () => {
    expect(names(sortCategories(categories, 'alphabetical'))).toEqual([
      'alimentari',
      'Benzina',
      'Casa',
      'zeta',
      'Altro',
    ]);
  });

  it('sorts a custom "Altro" like any other name', () => {
    expect(
      names(sortCategories([category('Zucchero'), category('altro')], 'alphabetical')),
    ).toEqual(['altro', 'Zucchero']);
  });

  it('orders most used first, ties alphabetical', () => {
    expect(names(sortCategories(categories, 'mostUsed'))).toEqual([
      'Altro',
      'alimentari',
      'Casa',
      'zeta',
      'Benzina',
    ]);
  });

  it('does not mutate its input', () => {
    const input = [category('b'), category('a')];
    sortCategories(input, 'alphabetical');
    expect(names(input)).toEqual(['b', 'a']);
  });
});
