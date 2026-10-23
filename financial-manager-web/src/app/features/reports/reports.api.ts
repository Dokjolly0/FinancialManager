import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';

import { api, query } from '../../core/api/api';

/** Period presets of the backend (internal/reports/period.go). */
export type ReportPreset =
  'last_30_days' | 'last_12_months' | 'current_month' | 'current_year' | 'all_time' | 'custom';

export interface ReportParams {
  preset: ReportPreset;
  wallet_id?: string | null;
  /** RFC 3339, for the custom preset. */
  from?: string | null;
  to?: string | null;
  include_adjustments?: boolean;
}

export interface ReportSummary {
  opening_balance_minor: number;
  closing_balance_minor: number;
  total_credits_minor: number;
  total_debits_minor: number;
  net_minor: number;
  savings_rate_percent?: number | null;
  transaction_count: number;
  currency: string;
  from?: string | null;
  to: string;
}

export interface TimeseriesPoint {
  period_start: string;
  credits_minor: number;
  debits_minor: number;
  net_minor: number;
  balance_minor: number;
}

export interface Timeseries {
  granularity: 'day' | 'week' | 'month' | string;
  points: TimeseriesPoint[] | null;
}

export interface BreakdownItem {
  key: string;
  label: string;
  amount_minor: number;
  percentage: number;
  transaction_count: number;
}

export interface Breakdown {
  group_by: 'category' | 'title' | string;
  credits: BreakdownItem[] | null;
  debits: BreakdownItem[] | null;
}

export interface MonthlyRow {
  month: string;
  credits_minor: number;
  debits_minor: number;
  net_minor: number;
}

export interface MonthlyComparison {
  months: MonthlyRow[] | null;
  spans_multiple_months: boolean;
}

/**
 * /v1/reports/* (plan.md sections 14.9, 18). Like the app, no timezone is
 * sent: the backend uses the profile's.
 */
@Injectable({ providedIn: 'root' })
export class ReportsApi {
  private readonly http = inject(HttpClient);

  summary(params: ReportParams): Promise<ReportSummary> {
    return this.get('/reports/summary', params);
  }

  timeseries(params: ReportParams): Promise<Timeseries> {
    return this.get('/reports/timeseries', params);
  }

  breakdown(params: ReportParams & { group_by: 'category' | 'title' }): Promise<Breakdown> {
    return this.get('/reports/breakdown', params);
  }

  monthlyComparison(params: ReportParams): Promise<MonthlyComparison> {
    return this.get('/reports/monthly-comparison', params);
  }

  private get<T>(path: string, params: ReportParams & { group_by?: string }): Promise<T> {
    return firstValueFrom(
      this.http.get<T>(api(path), {
        params: query({
          preset: params.preset,
          wallet_id: params.wallet_id,
          from: params.from,
          to: params.to,
          group_by: params.group_by,
          include_adjustments: params.include_adjustments ? true : undefined,
        }),
      }),
    );
  }
}
