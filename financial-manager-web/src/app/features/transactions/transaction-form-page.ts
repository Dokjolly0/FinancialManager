import { Location } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  computed,
  effect,
  inject,
  input,
  signal,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { fromDateTimeInput, toDateTimeInput } from '../../core/formatting/dates';
import { CategorySelect } from '../categories/category-select';
import { CategoriesStore } from '../categories/categories.store';
import { ImageField } from '../media/image-field';
import { AmountInput, Segmented, Switch } from '../../shared/ui/form-controls';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { WalletSelect } from '../wallets/wallet-select';
import { WalletsStore } from '../wallets/wallets.store';
import { TemplatesApi, TransactionTemplate, normalizeTitle } from './templates.api';
import { TitleAutocomplete } from './title-autocomplete';
import { Direction } from './transaction.model';
import { TransactionsApi } from './transactions.api';

/** Plain wallets: the backend rejects standard operations on meal-voucher wallets. */
const STANDARD_WALLET_TYPES = ['BANK', 'CASH', 'OTHER'] as const;

/**
 * New operation, edit operation (plan.md sections 7.6, 7.11, one form) and
 * "add a linked payment" (?linkTo=): the new operation joins the source's
 * payment group, prefilled from it except amount and date. A picked
 * template prefills category and description; editing the title away from
 * it drops the link (section 4.4). "Save as template" (or update the picked
 * one) runs after the operation is saved and never fails it.
 */
@Component({
  selector: 'app-transaction-form-page',
  imports: [
    AmountInput,
    CategorySelect,
    ImageField,
    InlineError,
    PageHeader,
    ReactiveFormsModule,
    Segmented,
    Spinner,
    Switch,
    TitleAutocomplete,
    TranslocoPipe,
    WalletSelect,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './transaction-form-page.html',
})
export class TransactionFormPage implements OnInit {
  /** Route param of /app/transactions/:id/edit. */
  readonly id = input<string>();
  /** Query param of /app/transactions/new?linkTo=. */
  readonly linkTo = input<string>();

  private readonly api = inject(TransactionsApi);
  private readonly templates = inject(TemplatesApi);
  private readonly categories = inject(CategoriesStore);
  private readonly wallets = inject(WalletsStore);
  private readonly router = inject(Router);
  private readonly location = inject(Location);
  private readonly transloco = inject(TranslocoService);
  private readonly toasts = inject(Toasts);
  private readonly errorText = inject(ErrorText);
  private readonly fb = inject(NonNullableFormBuilder);

  protected readonly walletTypes = [...STANDARD_WALLET_TYPES];
  protected readonly form = this.fb.group({
    direction: this.fb.control<Direction>('DEBIT'),
    amount: this.fb.control<number | null>(null),
    walletId: this.fb.control<string | null>(null),
    title: [''],
    categoryId: this.fb.control<string | null>(null),
    mediaId: this.fb.control<string | null>(null),
    occurredAt: [toDateTimeInput(new Date())],
    description: [''],
    saveAsTemplate: [false],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  protected readonly directionOptions = computed(() => [
    { value: 'DEBIT' as Direction, label: this.transloco.translate('debitsColumnLabel') },
    { value: 'CREDIT' as Direction, label: this.transloco.translate('creditsColumnLabel') },
  ]);

  protected readonly loading = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly errors = new FormErrors();
  private readonly version = signal<number | null>(null);
  /** The template picked from the suggestions, while the title still matches it. */
  protected readonly template = signal<TransactionTemplate | null>(null);

  protected readonly editing = computed(() => !!this.id());
  protected readonly title = computed(() =>
    this.editing()
      ? 'webEditOperation'
      : this.linkTo()
        ? 'addLinkedPaymentTooltip'
        : 'webNewOperation',
  );

  constructor() {
    // Default wallet: the first plain one, once the list is there, unless
    // something is already chosen (a loaded operation, a manual pick).
    effect(() => {
      const first = this.wallets.wallets().find((w) => w.type !== 'MEAL_VOUCHER');
      if (first && !this.form.controls.walletId.value && !this.loading()) {
        this.form.controls.walletId.setValue(first.id);
      }
    });
    // A title edited away from the picked template unlinks it.
    this.form.controls.title.valueChanges.subscribe((title) => {
      const template = this.template();
      if (template && normalizeTitle(title) !== normalizeTitle(template.title))
        this.template.set(null);
    });
  }

  ngOnInit(): void {
    const id = this.id() ?? this.linkTo();
    if (id) void this.load(id, !!this.id());
  }

  private async load(id: string, edit: boolean): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const t = await this.api.get(id);
      this.form.patchValue({
        direction: t.direction,
        walletId: t.wallet_id,
        title: t.title,
        description: t.description ?? '',
        categoryId: t.category_id ?? null,
        mediaId: t.media_id ?? null,
        // A linked payment keeps amount empty and the date now: a balance
        // payment rarely matches its deposit.
        amount: edit ? t.amount_minor : null,
        occurredAt: edit ? toDateTimeInput(new Date(t.occurred_at)) : toDateTimeInput(new Date()),
      });
      if (edit) this.version.set(t.version);
    } catch (error) {
      this.loadError.set(this.errorText.message(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected retry(): void {
    this.ngOnInit();
  }

  protected applyTemplate(template: TransactionTemplate): void {
    this.template.set(template);
    this.form.patchValue({
      title: template.title,
      description: template.default_description ?? this.form.controls.description.value,
      categoryId: this.categories.byId(template.default_category_id)?.id ?? null,
    });
  }

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    const codes: Record<string, string> = {};
    if (v.amount === null || v.amount <= 0) codes['amount_minor'] = 'AMOUNT_NOT_POSITIVE';
    if (!v.title.trim()) codes['title'] = 'REQUIRED_FIELD';
    if (!v.walletId) codes['wallet_id'] = 'REQUIRED_FIELD';
    if (!this.errors.check(codes)) return;

    const body = {
      wallet_id: v.walletId!,
      direction: v.direction,
      amount_minor: v.amount!,
      title: v.title.trim(),
      description: v.description.trim() || null,
      category_id: v.categoryId,
      template_id: this.template()?.id ?? null,
      media_id: v.mediaId,
      occurred_at: (fromDateTimeInput(v.occurredAt) ?? new Date()).toISOString(),
    };
    this.saving.set(true);
    try {
      const id = this.id();
      if (id) {
        await this.api.update(id, { ...body, version: this.version()! });
      } else {
        await this.api.create({
          ...body,
          currency: 'EUR',
          link_to_transaction_id: this.linkTo() ?? null,
        });
      }
      if (v.saveAsTemplate) await this.persistTemplate(body);
      this.toasts.success(this.transloco.translate('webSaved'));
      this.leave();
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }

  /** Best effort: the operation is saved, a template failure must not surface. */
  private async persistTemplate(body: {
    direction: Direction;
    title: string;
    category_id: string | null;
    description: string | null;
  }): Promise<void> {
    const fields = {
      title: body.title,
      default_category_id: body.category_id,
      default_description: body.description,
    };
    try {
      const template = this.template();
      if (template) await this.templates.update(template.id, fields);
      else await this.templates.create({ direction: body.direction, ...fields });
    } catch {
      // Swallowed by design, like the app.
    }
  }

  protected leave(): void {
    if (window.history.length > 1) this.location.back();
    else void this.router.navigateByUrl('/app/history');
  }
}
