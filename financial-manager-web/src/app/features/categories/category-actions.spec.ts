import { TestBed } from '@angular/core/testing';

import { provideTestI18n } from '../../../testing/i18n';
import { ErrorText } from '../../core/errors/error-text';
import { ConfirmOptions } from '../../shared/ui/confirm-dialog';
import { Overlay } from '../../shared/ui/overlay';
import { Toasts } from '../../shared/ui/toast';
import { CategoriesStore, Category } from './categories.store';
import { CategoryActions } from './category-actions';

const palestra: Category = {
  id: 'c1',
  name: 'Palestra',
  direction_scope: 'DEBIT',
  is_system: false,
  sort_order: 0,
  usage_count: 3,
};

describe('CategoryActions.remove', () => {
  let confirmAnswer: boolean;
  let asked: ConfirmOptions[];
  let removed: string[];

  beforeEach(() => {
    confirmAnswer = true;
    asked = [];
    removed = [];
    TestBed.configureTestingModule({
      providers: [
        provideTestI18n({
          deleteCategoryConfirmTitle: 'Delete “{name}”?',
          deleteCategoryInUseMessage:
            '{count, plural, =1{1 transaction left} other{{count} transactions left}}',
          deleteCategoryUnusedMessage: 'Unused',
          commonDelete: 'Delete',
        }),
        {
          provide: Overlay,
          useValue: {
            confirm: async (options: ConfirmOptions) => {
              asked.push(options);
              return confirmAnswer;
            },
          },
        },
        {
          provide: CategoriesStore,
          useValue: { remove: async (id: string) => void removed.push(id) },
        },
        { provide: Toasts, useValue: { error: () => undefined } },
        { provide: ErrorText, useValue: { message: () => 'error' } },
      ],
    });
  });

  it('warns how many transactions lose the category, then deletes', async () => {
    await TestBed.inject(CategoryActions).remove(palestra);
    expect(asked).toHaveLength(1);
    expect(asked[0].title).toBe('Delete “Palestra”?');
    expect(asked[0].message).toBe('3 transactions left');
    expect(asked[0].destructive).toBe(true);
    expect(removed).toEqual(['c1']);
  });

  it('says so when no transaction uses it', async () => {
    await TestBed.inject(CategoryActions).remove({ ...palestra, usage_count: 0 });
    expect(asked[0].message).toBe('Unused');
  });

  it('deletes nothing when cancelled', async () => {
    confirmAnswer = false;
    await TestBed.inject(CategoryActions).remove(palestra);
    expect(removed).toEqual([]);
  });
});
