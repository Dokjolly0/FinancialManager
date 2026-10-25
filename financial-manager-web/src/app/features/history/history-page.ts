import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  signal,
  untracked,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { History, Link, Search, SlidersHorizontal, Sparkles, X } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { formatDate, fromDateInput, toDateInput } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { formatMoney } from '../../core/formatting/money';
import { AppDatePipe, MoneyPipe } from '../../core/formatting/pipes';
import { SessionService } from '../../core/session/session.service';
import { Ledger } from '../../core/state/ledger';
import { Icon } from '../../shared/ui/icon';
import { InView } from '../../shared/ui/in-view';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, SkeletonList, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { CategoriesStore } from '../categories/categories.store';
import { TransactionRow } from '../transactions/transaction-row';
import { Transaction } from '../transactions/transaction.model';
import { TransactionsApi } from '../transactions/transactions.api';
import { WalletsStore } from '../wallets/wallets.store';
import {
  EMPTY_FILTER,
  HistoryFilter,
  TYPE_FILTERS,
  TypeFilter,
  activeCount,
  aiPrefill,
  filterFromParams,
  filterToParams,
  filterToQuery,
  groupByDay,
} from './history-filter';
import { HistoryFiltersDialog, TYPE_FILTER_KEYS } from './history-filters-dialog';

const PAGE_SIZE = 30;

/**
 * History (plan.md section 7.9): searchable, filterable list of every
 * operation, grouped by day with the day's net, loaded page by page as the
 * user scrolls (cursor pagination, section 17.2). Filters live in the URL.
 */
@Component({
  selector: 'app-history-page',
  imports: [
    AppDatePipe,
    EmptyState,
    Icon,
    InView,
    InlineError,
    MoneyPipe,
    PageHeader,
    RouterLink,
    SkeletonList,
    Spinner,
    TransactionRow,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './history-page.html',
})
export class HistoryPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly api = inject(TransactionsApi);
  private readonly ledger = inject(Ledger);
  private readonly overlay = inject(Overlay);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);
  private readonly errorText = inject(ErrorText);
  private readonly locale = inject(LocaleService);
  protected readonly session = inject(SessionService);
  protected readonly wallets = inject(WalletsStore);
  protected readonly categories = inject(CategoriesStore);

  protected readonly icons = { History, Link, Search, SlidersHorizontal, Sparkles, X };
  protected readonly types = TYPE_FILTERS;
  protected readonly typeKeys = TYPE_FILTER_KEYS;

  private readonly params = toSignal(this.route.queryParams, { initialValue: {} });
  protected readonly filter = computed(() => filterFromParams(this.params()));
  protected readonly active = computed(() => activeCount(this.filter()));
  /** Filters besides type and search, shown as removable chips. */
  protected readonly chips = computed(() => {
    const f = this.filter();
    const chips: { key: keyof HistoryFilter; label: string }[] = [];
    if (f.walletId)
      chips.push({ key: 'walletId', label: this.wallets.byId(f.walletId)?.name ?? '…' });
    if (f.categoryId)
      chips.push({ key: 'categoryId', label: this.categories.name(f.categoryId) ?? '…' });
    if (f.amountMin !== null)
      chips.push({ key: 'amountMin', label: `≥ ${this.money(f.amountMin)}` });
    if (f.amountMax !== null)
      chips.push({ key: 'amountMax', label: `≤ ${this.money(f.amountMax)}` });
    if (f.from)
      chips.push({
        key: 'from',
        label: `${this.transloco.translate('startDateLabel')}: ${this.day(f.from)}`,
      });
    if (f.to)
      chips.push({
        key: 'to',
        label: `${this.transloco.translate('endDateLabel')}: ${this.day(f.to)}`,
      });
    return chips;
  });

  protected readonly items = signal<Transaction[]>([]);
  private cursor: string | null = null;
  protected readonly hasMore = signal(false);
  protected readonly loading = signal(true);
  protected readonly loadingMore = signal(false);
  protected readonly error = signal<string | null>(null);
  private generation = 0;

  protected readonly days = computed(() => groupByDay(this.items()));
  protected readonly today = toDateInput(new Date());
  protected readonly yesterday = toDateInput(new Date(Date.now() - 86_400_000));

  private searchTimer: ReturnType<typeof setTimeout> | undefined;

  constructor() {
    // First page again whenever the filter or the ledger changes.
    effect(() => {
      const filter = this.filter();
      this.ledger.revision();
      untracked(() => void this.load(filter, true));
    });
  }

  private async load(filter: HistoryFilter, reset: boolean): Promise<void> {
    const generation = reset ? ++this.generation : this.generation;
    if (reset) {
      this.loading.set(true);
      this.error.set(null);
      this.cursor = null;
    } else {
      this.loadingMore.set(true);
    }
    try {
      const page = await this.api.list({
        ...filterToQuery(filter),
        limit: PAGE_SIZE,
        cursor: this.cursor,
      });
      if (generation !== this.generation) return;
      const rows = page.transactions ?? [];
      this.items.update((items) => (reset ? rows : [...items, ...rows]));
      this.cursor = page.next_cursor ?? null;
      this.hasMore.set(!!page.has_more && !!this.cursor);
    } catch (error) {
      if (generation !== this.generation) return;
      if (reset) this.error.set(this.errorText.message(error));
      else this.toasts.error(this.errorText.message(error));
    } finally {
      if (generation === this.generation) {
        this.loading.set(false);
        this.loadingMore.set(false);
      }
    }
  }

  protected loadMore(): void {
    if (this.hasMore() && !this.loading() && !this.loadingMore()) {
      void this.load(this.filter(), false);
    }
  }

  protected retry(): void {
    void this.load(this.filter(), true);
  }

  private update(changes: Partial<HistoryFilter>): void {
    void this.router.navigate([], {
      queryParams: filterToParams({ ...this.filter(), ...changes }),
      replaceUrl: true,
    });
  }

  protected setType(type: TypeFilter): void {
    this.update({ type });
  }

  protected onSearch(value: string): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.update({ title: value }), 350);
  }

  protected removeChip(key: keyof HistoryFilter): void {
    this.update({ [key]: EMPTY_FILTER[key] } as Partial<HistoryFilter>);
  }

  protected clearAll(): void {
    this.update(EMPTY_FILTER);
  }

  protected async openFilters(): Promise<void> {
    const result = await this.overlay.result<HistoryFilter, HistoryFilter>(HistoryFiltersDialog, {
      data: this.filter(),
      variant: 'drawer',
    });
    if (result) this.update(result);
  }

  protected analyzeWithAi(): void {
    const prefill = aiPrefill(this.filter());
    if ('problem' in prefill) {
      this.toasts.show(
        this.transloco.translate(
          prefill.problem === 'adjustments'
            ? 'aiHistoryAnalyzeAdjustments'
            : 'aiHistoryAnalyzeTransfers',
        ),
      );
      return;
    }
    void this.router.navigate(['/app/ai/new'], { queryParams: prefill.params });
  }

  private money(minor: number): string {
    return formatMoney(minor, 'EUR', this.locale.intl());
  }

  private day(value: string): string {
    const date = fromDateInput(value);
    return date ? formatDate(date, 'date', this.locale.intl()) : value;
  }
}
