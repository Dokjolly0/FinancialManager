import {
  ChangeDetectionStrategy,
  Component,
  computed,
  inject,
  resource,
  signal,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import type { EChartsCoreOption } from 'echarts/core';
import { NgxEchartsDirective, provideEchartsCore } from 'ngx-echarts';
import { ChartColumn, History, Sparkles, Table } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { formatDate } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { formatMoney } from '../../core/formatting/money';
import { AppDatePipe, MoneyPipe, PercentPipe } from '../../core/formatting/pipes';
import { SessionService } from '../../core/session/session.service';
import { Ledger } from '../../core/state/ledger';
import { ThemeService } from '../../core/theme/theme.service';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError } from '../../shared/ui/states';
import { WalletsStore } from '../wallets/wallets.store';
import { axisStyle, baseOptions, chartColors, echarts } from './charts';
import {
  PRESETS,
  PRESET_KEYS,
  ReportFilter,
  reportFilterFromParams,
  reportFilterToParams,
  reportParams,
} from './report-filter';
import { ReportPreset, ReportsApi } from './reports.api';

/**
 * Reports (plan.md sections 7.12, 18): period (presets or a custom range),
 * wallet, adjustments on or off; summary, balance trend, monthly comparison
 * (only when the period spans months, section 18.8) and the breakdown by
 * category or title. Every chart has a table view.
 */
@Component({
  selector: 'app-report-page',
  imports: [
    AppDatePipe,
    EmptyState,
    Icon,
    InlineError,
    MoneyPipe,
    NgxEchartsDirective,
    PageHeader,
    PercentPipe,
    RouterLink,
    TranslocoPipe,
  ],
  providers: [provideEchartsCore({ echarts })],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './report-page.html',
})
export class ReportPage {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly api = inject(ReportsApi);
  private readonly ledger = inject(Ledger);
  private readonly theme = inject(ThemeService);
  private readonly locale = inject(LocaleService);
  private readonly transloco = inject(TranslocoService);
  protected readonly errorText = inject(ErrorText);
  protected readonly wallets = inject(WalletsStore);
  protected readonly session = inject(SessionService);

  protected readonly icons = { ChartColumn, History, Sparkles, Table };
  protected readonly presets = PRESETS;
  protected readonly presetKeys = PRESET_KEYS;

  /** Emits once a language is loaded: chart labels recompute with it. */
  private readonly translation = toSignal(this.transloco.selectTranslation());

  private readonly queryParams = toSignal(this.route.queryParams, { initialValue: {} });
  protected readonly filter = computed(() => reportFilterFromParams(this.queryParams()));
  private readonly params = computed(() => reportParams(this.filter()));

  protected readonly trendAsTable = signal(false);
  protected readonly monthlyAsTable = signal(false);

  protected readonly data = resource({
    params: () => {
      const params = this.params();
      return params ? { params, revision: this.ledger.revision() } : undefined;
    },
    loader: async ({ params: { params } }) => {
      const [summary, timeseries, monthly] = await Promise.all([
        this.api.summary(params),
        this.api.timeseries(params),
        this.api.monthlyComparison(params),
      ]);
      return { summary, timeseries, monthly };
    },
  });

  /** Reloaded alone when only the grouping changes. */
  protected readonly breakdown = resource({
    params: () => {
      const params = this.params();
      return params
        ? {
            params: { ...params, group_by: this.filter().groupBy },
            revision: this.ledger.revision(),
          }
        : undefined;
    },
    loader: ({ params: { params } }) => this.api.breakdown(params),
  });

  protected readonly points = computed(() => this.data.value()?.timeseries.points ?? []);
  protected readonly months = computed(() => this.data.value()?.monthly.months ?? []);
  protected readonly currency = computed(() => this.data.value()?.summary.currency ?? 'EUR');
  protected readonly breakdownTab = signal<'debits' | 'credits'>('debits');
  protected readonly breakdownItems = computed(() => {
    const b = this.breakdown.value();
    return (this.breakdownTab() === 'debits' ? b?.debits : b?.credits) ?? [];
  });

  /** Cumulative balance at the backend's granularity (day under 46 days, else month). */
  protected readonly trendOptions = computed<EChartsCoreOption>(() => {
    this.theme.dark();
    const colors = chartColors();
    const locale = this.locale.intl();
    const daily = this.data.value()?.timeseries.granularity === 'day';
    const money = (minor: number) => formatMoney(minor, this.currency(), locale);
    const points = this.points();
    return {
      ...baseOptions(colors),
      legend: { show: false },
      grid: { left: 8, right: 16, top: 16, bottom: 8, containLabel: true },
      tooltip: {
        ...(baseOptions(colors)['tooltip'] as object),
        valueFormatter: (value: number) => money(value),
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: points.map((p) =>
          formatDate(p.period_start, daily ? 'dayMonth' : 'monthYear', locale),
        ),
        ...axisStyle(colors),
        splitLine: { show: false },
      },
      yAxis: {
        type: 'value',
        ...axisStyle(colors),
        axisLabel: {
          color: colors.muted,
          fontSize: 11,
          formatter: (value: number) =>
            formatMoney(value, this.currency(), locale, { compact: true }),
        },
      },
      series: [
        {
          name: 'balance',
          type: 'line',
          smooth: 0.25,
          showSymbol: points.length < 40,
          symbolSize: 8,
          lineStyle: { width: 2, color: colors.primary },
          itemStyle: { color: colors.primary, borderColor: colors.surface, borderWidth: 2 },
          areaStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: colors.primary + '33' },
              { offset: 1, color: colors.primary + '00' },
            ]),
          },
          data: points.map((p) => p.balance_minor),
        },
      ],
    };
  });

  protected readonly monthlyOptions = computed<EChartsCoreOption>(() => {
    this.theme.dark();
    this.translation();
    const colors = chartColors();
    const locale = this.locale.intl();
    const money = (minor: number) => formatMoney(minor, this.currency(), locale);
    const months = this.months();
    const bar = (name: string, color: string, values: number[]) => ({
      name,
      type: 'bar',
      barMaxWidth: 22,
      barGap: '12%',
      itemStyle: { color, borderRadius: [4, 4, 0, 0] },
      data: values,
    });
    return {
      ...baseOptions(colors),
      tooltip: {
        ...(baseOptions(colors)['tooltip'] as object),
        axisPointer: { type: 'shadow', shadowStyle: { color: colors.border + '55' } },
        valueFormatter: (value: number) => money(value),
      },
      xAxis: {
        type: 'category',
        data: months.map((m) => formatDate(m.month, 'monthShort', locale)),
        ...axisStyle(colors),
        splitLine: { show: false },
      },
      yAxis: {
        type: 'value',
        ...axisStyle(colors),
        axisLabel: {
          color: colors.muted,
          fontSize: 11,
          formatter: (value: number) =>
            formatMoney(value, this.currency(), locale, { compact: true }),
        },
      },
      series: [
        bar(
          this.label('creditsColumnLabel'),
          colors.income,
          months.map((m) => m.credits_minor),
        ),
        bar(
          this.label('debitsColumnLabel'),
          colors.expenses,
          months.map((m) => m.debits_minor),
        ),
      ],
    };
  });

  private label(key: string): string {
    return this.transloco.translate(key);
  }

  protected update(changes: Partial<ReportFilter>): void {
    void this.router.navigate([], {
      queryParams: reportFilterToParams({ ...this.filter(), ...changes }),
      replaceUrl: true,
    });
  }

  protected setPreset(preset: ReportPreset): void {
    this.update({ preset });
  }
}
