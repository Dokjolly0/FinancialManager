import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  computed,
  inject,
  input,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';

import { ErrorText } from '../../core/errors/error-text';
import { MoneyPipe } from '../../core/formatting/pipes';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, SkeletonList, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { WalletDenomination } from './wallet.model';
import { WalletsApi } from './wallets.api';

/**
 * Banknotes and coins of a cash wallet: one row per EUR denomination (the
 * backend fills in zero counts), each can be hidden for denominations the
 * user never handles, without losing a counted value. Informational only:
 * never reconciled with the balance.
 */
@Component({
  selector: 'app-denominations-page',
  imports: [InlineError, MoneyPipe, PageHeader, SkeletonList, Spinner, TranslocoPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-2xl">
      <app-page-header
        [title]="'walletDenominationsScreenTitle' | transloco"
        [back]="['/app/account/wallets', id(), 'edit']"
        [backLabel]="'backAction' | transloco"
      />
      @if (loading()) {
        <div class="card overflow-hidden"><app-skeleton-list [rows]="6" /></div>
      } @else if (loadError()) {
        <div class="card"><app-inline-error [message]="loadError()!" (retry)="load()" /></div>
      } @else {
        <div class="card divide-y divide-border overflow-hidden">
          @for (row of rows(); track row.denomination_minor; let i = $index) {
            <div class="flex items-center gap-4 px-4 py-3" [class.opacity-50]="!row.enabled">
              <span class="tabular w-24 font-semibold text-fg">{{
                row.denomination_minor | money
              }}</span>
              <label class="sr-only" [for]="'den-' + i">{{
                'denominationCountLabel' | transloco
              }}</label>
              <input
                [id]="'den-' + i"
                type="number"
                min="0"
                step="1"
                class="input tabular h-10 w-24 text-center"
                [value]="row.count"
                [disabled]="!row.enabled"
                (input)="setCount(i, $any($event.target).value)"
              />
              <span class="tabular flex-1 text-right text-sm text-fg-muted">
                {{ row.enabled ? (row.count * row.denomination_minor | money) : '' }}
              </span>
              <button
                type="button"
                role="switch"
                class="relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors"
                [class]="row.enabled ? 'bg-primary' : 'bg-border'"
                [attr.aria-checked]="row.enabled"
                [attr.aria-label]="row.denomination_minor | money"
                (click)="toggle(i)"
              >
                <span
                  class="inline-block h-5 w-5 rounded-full bg-white shadow transition-transform"
                  [class]="row.enabled ? 'translate-x-5.5' : 'translate-x-0.5'"
                ></span>
              </button>
            </div>
          }
          <div class="flex items-center justify-between bg-surface-2/60 px-4 py-3">
            <span class="text-sm font-semibold text-fg">{{ 'webTotal' | transloco }}</span>
            <span class="tabular text-lg font-bold text-fg">{{ total() | money }}</span>
          </div>
        </div>
        @if (error()) {
          <p class="field-error mt-4" role="alert">{{ error() }}</p>
        }
        <div class="mt-6 flex justify-end">
          <button type="button" class="btn btn-primary" [disabled]="saving()" (click)="save()">
            @if (saving()) {
              <app-spinner />
            }
            {{ 'saveDenominationsAction' | transloco }}
          </button>
        </div>
      }
    </div>
  `,
})
export class DenominationsPage implements OnInit {
  readonly id = input.required<string>();

  private readonly api = inject(WalletsApi);
  private readonly router = inject(Router);
  private readonly errors = inject(ErrorText);
  private readonly toasts = inject(Toasts);
  private readonly transloco = inject(TranslocoService);

  protected readonly rows = signal<WalletDenomination[]>([]);
  protected readonly loading = signal(true);
  protected readonly loadError = signal<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly error = signal<string | null>(null);
  protected readonly total = computed(() =>
    this.rows()
      .filter((row) => row.enabled)
      .reduce((sum, row) => sum + row.count * row.denomination_minor, 0),
  );

  ngOnInit(): void {
    void this.load();
  }

  protected async load(): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      this.rows.set(await this.api.denominations(this.id()));
    } catch (error) {
      this.loadError.set(this.errors.message(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected setCount(index: number, raw: string): void {
    const count = Math.max(0, Math.trunc(Number(raw) || 0));
    this.rows.update((rows) => rows.map((row, i) => (i === index ? { ...row, count } : row)));
  }

  protected toggle(index: number): void {
    this.rows.update((rows) =>
      rows.map((row, i) => (i === index ? { ...row, enabled: !row.enabled } : row)),
    );
  }

  protected async save(): Promise<void> {
    this.saving.set(true);
    this.error.set(null);
    try {
      await this.api.replaceDenominations(this.id(), this.rows());
      this.toasts.success(this.transloco.translate('webSaved'));
      await this.router.navigate(['/app/account/wallets', this.id(), 'edit']);
    } catch (error) {
      this.error.set(this.errors.message(error));
    } finally {
      this.saving.set(false);
    }
  }
}
