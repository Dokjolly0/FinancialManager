import { ChangeDetectionStrategy, Component, inject, resource } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslocoPipe } from '@jsverse/transloco';
import { ChevronRight, Link } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { MoneyPipe } from '../../core/formatting/pipes';
import { Ledger } from '../../core/state/ledger';
import { Icon } from '../../shared/ui/icon';
import { PageHeader } from '../../shared/ui/page-header';
import { EmptyState, InlineError, SkeletonList } from '../../shared/ui/states';
import { TransactionsApi } from './transactions.api';

/**
 * Linked payments: every group of two or more operations linked as
 * installments of one expense, with the combined total. A row opens the
 * group's earliest member, whose detail lists them all.
 */
@Component({
  selector: 'app-payment-groups-page',
  imports: [
    EmptyState,
    Icon,
    InlineError,
    MoneyPipe,
    PageHeader,
    RouterLink,
    SkeletonList,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="mx-auto max-w-3xl">
      <app-page-header
        [title]="'linkedPaymentsSectionTitle' | transloco"
        back="/app/history"
        [backLabel]="'backAction' | transloco"
      />
      <div class="card divide-y divide-border overflow-hidden">
        @if (groups.isLoading() && !groups.hasValue()) {
          <app-skeleton-list [rows]="4" />
        } @else if (groups.error()) {
          <app-inline-error
            [message]="errorText.message(groups.error())"
            (retry)="groups.reload()"
          />
        } @else {
          @for (group of groups.value(); track group.payment_group_id) {
            <a
              class="list-row"
              [routerLink]="['/app/transactions', group.representative_transaction_id]"
            >
              <span
                class="grid h-10 w-10 place-items-center rounded-xl bg-primary-soft text-primary"
              >
                <app-icon [icon]="icons.Link" [size]="18" />
              </span>
              <span class="min-w-0 flex-1">
                <span class="block truncate text-sm font-medium text-fg">{{
                  group.representative_title
                }}</span>
                <span class="block text-xs text-fg-muted">{{
                  'linkedPaymentsMemberCountLabel' | transloco: { count: group.member_count }
                }}</span>
              </span>
              <span class="tabular text-sm font-semibold text-fg">{{
                group.net_amount_minor | money: group.currency
              }}</span>
              <app-icon [icon]="icons.ChevronRight" [size]="18" class="text-fg-muted" />
            </a>
          } @empty {
            <app-empty-state
              [message]="'linkedPaymentsEmptyStateMessage' | transloco"
              [icon]="icons.Link"
            />
          }
        }
      </div>
    </div>
  `,
})
export class PaymentGroupsPage {
  private readonly api = inject(TransactionsApi);
  private readonly ledger = inject(Ledger);
  protected readonly errorText = inject(ErrorText);
  protected readonly icons = { ChevronRight, Link };

  protected readonly groups = resource({
    params: () => ({ revision: this.ledger.revision() }),
    loader: () => this.api.paymentGroups(),
  });
}
