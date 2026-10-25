import {
  ChangeDetectionStrategy,
  Component,
  computed,
  effect,
  inject,
  resource,
  signal,
  untracked,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { BotMessageSquare, Sparkles, X } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { fromDateInput } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { formatMoney } from '../../core/formatting/money';
import { Switch } from '../../shared/ui/form-controls';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, Spinner } from '../../shared/ui/states';
import { CategoriesStore } from '../categories/categories.store';
import { WalletsStore } from '../wallets/wallets.store';
import { AiDraft } from './ai-draft';
import {
  DayRange,
  QUICK_PERIODS,
  QuickPeriod,
  matchQuick,
  periodFields,
  quickRange,
} from './ai-period';
import { AiApi } from './ai.api';
import {
  AI_COMPACT_DEFAULT_TRANSACTIONS,
  AI_COMPACT_MAX_TRANSACTIONS,
  AI_DEFAULT_MAX_TRANSACTIONS,
  AI_INSTRUCTIONS_MAX_LENGTH,
  AI_MAX_TRANSACTIONS,
  AI_SECTIONS,
  AiAnalysisRequest,
  AiDataSection,
  AiFilters,
  AiPreset,
  PROVIDER_LABELS,
  SECTION_KEYS,
} from './ai.model';

/**
 * A new analysis (plan.md section 32.7): the account that runs it, the
 * preset (or a custom question), period, wallets, filters (from History),
 * data sections, single transactions, anonymized titles, adjustments,
 * compact profile. "Preview" builds the exact prompt first; consent is asked
 * here when missing, like the app.
 */
@Component({
  selector: 'app-ai-setup-page',
  imports: [
    EmptyState,
    FormsModule,
    Icon,
    InlineError,
    PageHeader,
    RouterLink,
    Spinner,
    Switch,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './ai-setup-page.html',
})
export class AiSetupPage {
  protected readonly ai = inject(AiApi);
  private readonly draft = inject(AiDraft);
  private readonly router = inject(Router);
  private readonly overlay = inject(Overlay);
  private readonly transloco = inject(TranslocoService);
  private readonly locale = inject(LocaleService);
  protected readonly errorText = inject(ErrorText);
  protected readonly wallets = inject(WalletsStore);
  private readonly categories = inject(CategoriesStore);
  private readonly params = toSignal(inject(ActivatedRoute).queryParams, { initialValue: {} });

  protected readonly icons = { BotMessageSquare, Sparkles, X };
  protected readonly quickPeriods = QUICK_PERIODS;
  protected readonly sectionList = AI_SECTIONS;
  protected readonly sectionKeys = SECTION_KEYS;
  protected readonly questionMax = AI_INSTRUCTIONS_MAX_LENGTH;

  protected readonly presets = resource({ loader: () => this.ai.presets() });

  protected readonly credentialId = signal<string | null>(null);
  protected readonly preset = signal<AiPreset | null>(null);
  protected readonly question = signal('');
  protected readonly questionError = signal<string | null>(null);
  protected readonly range = signal<DayRange>(quickRange('last12Months'));
  protected readonly walletIds = signal<string[]>([]);
  protected readonly filters = signal<AiFilters>({});
  protected readonly fromHistory = signal(false);
  protected readonly sections = signal<AiDataSection[]>([]);
  protected readonly includeTransactions = signal(false);
  protected readonly maxTransactions = signal(AI_DEFAULT_MAX_TRANSACTIONS);
  protected readonly anonymize = signal(false);
  protected readonly includeAdjustments = signal(false);
  protected readonly compact = signal(false);
  protected readonly previewing = signal(false);
  protected readonly error = signal<string | null>(null);

  protected readonly quick = computed(() => matchQuick(this.range()));
  protected readonly sliderMin = computed(() => (this.compact() ? 10 : 50));
  protected readonly sliderMax = computed(() =>
    this.compact() ? AI_COMPACT_MAX_TRANSACTIONS : AI_MAX_TRANSACTIONS,
  );

  /** Removable chips for the filters that came from History. */
  protected readonly filterChips = computed(() => {
    const f = this.filters();
    const t = (key: string, params?: Record<string, unknown>) =>
      this.transloco.translate(key, params);
    const money = (minor: number) => formatMoney(minor, 'EUR', this.locale.intl());
    const chips: { key: keyof AiFilters; label: string }[] = [];
    if (f.direction)
      chips.push({
        key: 'direction',
        label: t(f.direction === 'DEBIT' ? 'aiFilterExpenses' : 'aiFilterIncome'),
      });
    if (f.category_id)
      chips.push({
        key: 'category_id',
        label: t('aiFilterCategory', { name: this.categories.name(f.category_id) ?? '…' }),
      });
    if (f.title) chips.push({ key: 'title', label: t('aiFilterTitle', { text: f.title }) });
    if (f.amount_min_minor !== undefined)
      chips.push({
        key: 'amount_min_minor',
        label: t('aiFilterAmountMin', { amount: money(f.amount_min_minor) }),
      });
    if (f.amount_max_minor !== undefined)
      chips.push({
        key: 'amount_max_minor',
        label: t('aiFilterAmountMax', { amount: money(f.amount_max_minor) }),
      });
    return chips;
  });

  constructor() {
    this.ai.settings.reload();
    // The account that runs it: the active one, else the first usable.
    effect(() => {
      const credentials = this.ai.credentials();
      const active = this.ai.settings.value()?.active?.id;
      untracked(() => {
        if (!credentials.some((c) => c.id === this.credentialId())) {
          this.credentialId.set(
            (credentials.find((c) => c.id === active) ?? credentials[0])?.id ?? null,
          );
        }
      });
    });
    // First preset once they load.
    effect(() => {
      const presets = this.presets.value();
      if (presets?.length && !untracked(() => this.preset()))
        untracked(() => this.selectPreset(presets[0]));
    });
    this.applyPrefill();
  }

  /** "Analyze with AI" from History: its filters as query params (history-filter.ts aiPrefill). */
  private applyPrefill(): void {
    const p = this.params() as Record<string, string | undefined>;
    if (!p['fromHistory']) return;
    this.fromHistory.set(true);
    const int = (value?: string) =>
      value !== undefined && /^\d+$/.test(value) ? Number(value) : undefined;
    const filters: AiFilters = {
      ...(p['direction'] === 'DEBIT' || p['direction'] === 'CREDIT'
        ? { direction: p['direction'] }
        : {}),
      ...(p['category'] ? { category_id: p['category'] } : {}),
      ...(p['title'] ? { title: p['title'] } : {}),
      ...(int(p['min']) !== undefined ? { amount_min_minor: int(p['min']) } : {}),
      ...(int(p['max']) !== undefined ? { amount_max_minor: int(p['max']) } : {}),
    };
    this.filters.set(filters);
    if (p['wallet']) this.walletIds.set([p['wallet']]);
    const from = p['from'] && fromDateInput(p['from']) ? p['from'] : null;
    const to = p['to'] && fromDateInput(p['to']) ? p['to'] : null;
    this.range.set({ from, to });
  }

  protected credentialLabel(id: string): string {
    const c = this.ai.credentials().find((credential) => credential.id === id);
    if (!c) return '';
    return `${PROVIDER_LABELS[c.provider] ?? this.transloco.translate('aiProviderCompatible')} · ${c.model}`;
  }

  protected selectPreset(preset: AiPreset): void {
    this.preset.set(preset);
    this.sections.set([...preset.default_sections]);
    this.includeTransactions.set(
      preset.default_include_transactions ||
        (this.ai.settings.value()?.defaults.include_transactions ?? false),
    );
    this.anonymize.set(this.ai.settings.value()?.defaults.anonymize_titles ?? false);
    this.questionError.set(null);
  }

  protected setQuick(period: QuickPeriod): void {
    this.range.set(quickRange(period));
  }

  /** Keeps the range valid: a "from" after "to" moves the other bound along. */
  protected setBound(bound: 'from' | 'to', value: string): void {
    const next = { ...this.range(), [bound]: value || null };
    if (next.from && next.to && next.from > next.to) {
      if (bound === 'from') next.to = next.from;
      else next.from = next.to;
    }
    this.range.set(next);
  }

  protected toggleWallet(id: string | null): void {
    if (id === null) {
      this.walletIds.set([]);
      return;
    }
    this.walletIds.update((ids) => (ids.includes(id) ? ids.filter((x) => x !== id) : [...ids, id]));
  }

  protected toggleSection(section: AiDataSection): void {
    this.sections.update((list) =>
      list.includes(section) ? list.filter((s) => s !== section) : [...list, section],
    );
  }

  protected removeFilter(key: keyof AiFilters): void {
    this.filters.update((filters) => {
      const next = { ...filters };
      delete next[key];
      return next;
    });
  }

  protected setCompact(compact: boolean): void {
    this.compact.set(compact);
    this.maxTransactions.set(
      compact ? AI_COMPACT_DEFAULT_TRANSACTIONS : AI_DEFAULT_MAX_TRANSACTIONS,
    );
  }

  protected async preview(): Promise<void> {
    const preset = this.preset();
    const settings = this.ai.settings.value();
    if (!preset || !settings) return;
    const custom = preset.id === 'CUSTOM';
    if (custom && !this.question().trim()) {
      this.questionError.set(this.errorText.code('REQUIRED_FIELD'));
      return;
    }
    if (settings.consent.required) {
      const { AiConsentDialog } = await import('./ai-consent-dialog');
      const accepted = await this.overlay.result<boolean, number>(AiConsentDialog, {
        data: settings.consent.current_version,
        variant: 'drawer',
      });
      if (!accepted) return;
    }
    const filters = this.filters();
    const request: AiAnalysisRequest = {
      preset: preset.id,
      target: 'cloud',
      ...(this.credentialId() ? { credential_id: this.credentialId()! } : {}),
      period: periodFields(this.range()),
      wallet_ids: this.walletIds(),
      options: {
        sections: this.sections(),
        include_transactions: this.includeTransactions(),
        max_transactions: this.maxTransactions(),
        anonymize_titles: this.anonymize(),
        include_adjustments: this.includeAdjustments(),
        ...(Object.keys(filters).length ? { filters } : {}),
        ...(this.compact() ? { profile: 'compact' as const } : {}),
      },
      instructions: custom ? this.question().trim() : null,
    };
    this.previewing.set(true);
    this.error.set(null);
    try {
      const preview = await this.ai.preview(request);
      this.draft.set(request, preview, this.credentialLabel(this.credentialId() ?? ''));
      await this.router.navigateByUrl('/app/ai/preview');
    } catch (error) {
      this.error.set(this.errorText.message(error));
    } finally {
      this.previewing.set(false);
    }
  }
}
