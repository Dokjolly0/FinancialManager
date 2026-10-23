import {
  ChangeDetectionStrategy,
  Component,
  OnInit,
  computed,
  inject,
  input,
  signal,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NonNullableFormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslocoPipe, TranslocoService } from '@jsverse/transloco';
import { Archive, Banknote, CalendarClock, ChevronRight, SlidersHorizontal, Ticket } from 'lucide';

import { ErrorText } from '../../core/errors/error-text';
import { FormErrors } from '../../core/errors/form-errors';
import { fromDateInput, toDateInput } from '../../core/formatting/dates';
import { LocaleService } from '../../core/formatting/locale.service';
import { MoneyPipe } from '../../core/formatting/pipes';
import { formatMoney } from '../../core/formatting/money';
import { SessionService } from '../../core/session/session.service';
import { AmountInput, Segmented, SegmentOption } from '../../shared/ui/form-controls';
import { Icon } from '../../shared/ui/icon';
import { Overlay } from '../../shared/ui/overlay';
import { PageHeader } from '../../shared/ui/page-header';
import { InlineError, Spinner } from '../../shared/ui/states';
import { Toasts } from '../../shared/ui/toast';
import { Transaction } from '../transactions/transaction.model';
import { TransactionsApi } from '../transactions/transactions.api';
import { WalletDialogs } from './wallet-dialogs';
import { WALLET_ICONS } from './wallet-icons';
import {
  DEFAULT_VOUCHER_EXPIRY,
  DEFAULT_WALLET_COLOR,
  DEFAULT_WALLET_ICON,
  WALLET_COLORS,
  WALLET_ICON_KEYS,
  WALLET_PURPOSE_MAX_LENGTH,
  Wallet,
  WalletType,
} from './wallet.model';
import { WalletsApi } from './wallets.api';
import { WALLET_TYPE_KEYS } from './wallets-page';

/**
 * Create or edit a wallet. The type can't cross the meal-voucher boundary
 * once a wallet exists (the backend would strand its voucher value); a
 * voucher wallet's unit value is fixed at creation. Editing also reaches the
 * balance adjustment, the opening balance, cash denominations, voucher lots
 * and archiving.
 */
@Component({
  selector: 'app-wallet-form-page',
  imports: [
    AmountInput,
    Icon,
    InlineError,
    MoneyPipe,
    PageHeader,
    ReactiveFormsModule,
    RouterLink,
    Segmented,
    Spinner,
    TranslocoPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './wallet-form-page.html',
})
export class WalletFormPage implements OnInit {
  /** From the route: absent for a new wallet. */
  readonly id = input<string>();

  private readonly walletsApi = inject(WalletsApi);
  private readonly transactionsApi = inject(TransactionsApi);
  private readonly dialogs = inject(WalletDialogs);
  private readonly overlay = inject(Overlay);
  private readonly router = inject(Router);
  private readonly transloco = inject(TranslocoService);
  private readonly locale = inject(LocaleService);
  private readonly toasts = inject(Toasts);
  private readonly errorText = inject(ErrorText);
  private readonly fb = inject(NonNullableFormBuilder);
  protected readonly session = inject(SessionService);

  protected readonly icons = {
    Archive,
    Banknote,
    CalendarClock,
    ChevronRight,
    SlidersHorizontal,
    Ticket,
  };
  protected readonly iconKeys = WALLET_ICON_KEYS;
  protected readonly walletIcons = WALLET_ICONS;
  protected readonly colors = WALLET_COLORS;
  protected readonly purposeMax = WALLET_PURPOSE_MAX_LENGTH;

  protected readonly form = this.fb.group({
    name: [''],
    purpose: [''],
    type: this.fb.control<WalletType>('OTHER'),
    icon: [DEFAULT_WALLET_ICON],
    color: [DEFAULT_WALLET_COLOR],
    openingBalance: this.fb.control<number | null>(0),
    voucherUnitValue: this.fb.control<number | null>(null),
    cutoffMonth: [DEFAULT_VOUCHER_EXPIRY.cutoffMonth],
    expiryMonth: [DEFAULT_VOUCHER_EXPIRY.month],
    expiryDay: [DEFAULT_VOUCHER_EXPIRY.day],
    initialQuantity: this.fb.control<number | null>(0),
    loadedAt: [toDateInput(new Date())],
  });
  protected readonly values = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  protected readonly existing = signal<Wallet | null>(null);
  protected readonly openingBalance = signal<Transaction | null>(null);
  protected readonly loading = signal(false);
  protected readonly loadError = signal<string | null>(null);
  protected readonly saving = signal(false);
  protected readonly archiving = signal(false);
  protected readonly errors = new FormErrors();

  protected readonly editing = computed(() => !!this.id());
  protected readonly isVoucher = computed(() => this.values().type === 'MEAL_VOUCHER');

  /** Segments on the same side of the meal-voucher boundary as the existing wallet. */
  protected readonly typeOptions = computed<SegmentOption<WalletType>[]>(() => {
    const all: WalletType[] = ['CASH', 'BANK', 'OTHER', 'MEAL_VOUCHER'];
    const existing = this.existing();
    const allowed = existing
      ? all.filter((type) => (type === 'MEAL_VOUCHER') === (existing.type === 'MEAL_VOUCHER'))
      : all;
    return allowed.map((value) => ({
      value,
      label: this.transloco.translate(WALLET_TYPE_KEYS[value]),
    }));
  });

  protected readonly months = computed(() => {
    const format = new Intl.DateTimeFormat(this.locale.intl(), { month: 'long' });
    return Array.from({ length: 12 }, (_, i) => ({
      value: i + 1,
      label: format.format(new Date(2024, i, 1)),
    }));
  });
  protected readonly days = Array.from({ length: 31 }, (_, i) => i + 1);

  async ngOnInit(): Promise<void> {
    const id = this.id();
    if (id) await this.load(id);
  }

  private async load(id: string): Promise<void> {
    this.loading.set(true);
    this.loadError.set(null);
    try {
      const [wallet, opening] = await Promise.all([
        this.walletsApi.get(id),
        this.transactionsApi.openingBalance(id),
      ]);
      this.existing.set(wallet);
      this.openingBalance.set(opening);
      this.form.patchValue({
        name: wallet.name,
        purpose: wallet.purpose ?? '',
        type: wallet.type,
        icon: wallet.icon,
        color: wallet.color,
        voucherUnitValue: wallet.voucher_unit_value_minor ?? null,
        cutoffMonth: wallet.voucher_expiry_cutoff_month ?? DEFAULT_VOUCHER_EXPIRY.cutoffMonth,
        expiryMonth: wallet.voucher_expiry_month ?? DEFAULT_VOUCHER_EXPIRY.month,
        expiryDay: wallet.voucher_expiry_day ?? DEFAULT_VOUCHER_EXPIRY.day,
      });
    } catch (error) {
      this.loadError.set(this.errorText.message(error));
    } finally {
      this.loading.set(false);
    }
  }

  protected reload(): void {
    const id = this.id();
    if (id) void this.load(id);
  }

  protected async submit(): Promise<void> {
    const v = this.form.getRawValue();
    const name = v.name.trim();
    if (!this.errors.check(name ? {} : { name: 'REQUIRED_FIELD' })) return;
    const voucher = v.type === 'MEAL_VOUCHER';
    const fields = {
      name,
      type: v.type,
      icon: v.icon,
      color: v.color,
      purpose: v.purpose.trim() || null,
      voucher_expiry_cutoff_month: voucher ? v.cutoffMonth : null,
      voucher_expiry_month: voucher ? v.expiryMonth : null,
      voucher_expiry_day: voucher ? v.expiryDay : null,
    };
    this.saving.set(true);
    try {
      const existing = this.existing();
      if (existing) {
        await this.walletsApi.update(existing.id, { ...fields, version: existing.version });
      } else if (voucher) {
        await this.walletsApi.create({
          ...fields,
          voucher_unit_value_minor: v.voucherUnitValue,
          initial_voucher_quantity: Math.max(0, Math.trunc(Number(v.initialQuantity ?? 0))),
          voucher_loaded_at: (fromDateInput(v.loadedAt) ?? new Date()).toISOString(),
        });
      } else {
        await this.walletsApi.create({ ...fields, opening_balance_minor: v.openingBalance ?? 0 });
      }
      this.toasts.success(this.transloco.translate('webSaved'));
      await this.router.navigateByUrl('/app/account/wallets');
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.saving.set(false);
    }
  }

  protected async adjust(): Promise<void> {
    const wallet = this.existing();
    if (wallet && (await this.dialogs.adjustBalance(wallet))) this.reload();
  }

  protected async editOpeningBalance(): Promise<void> {
    const transaction = this.openingBalance();
    if (transaction && (await this.dialogs.editAmountDate(transaction, 'opening-balance')))
      this.reload();
  }

  protected async archive(): Promise<void> {
    const wallet = this.existing();
    if (!wallet) return;
    const balance = formatMoney(wallet.current_balance_minor, wallet.currency, this.locale.intl());
    const confirmed = await this.overlay.confirm({
      title: this.transloco.translate('archiveWalletConfirmTitle'),
      message:
        wallet.current_balance_minor === 0
          ? this.transloco.translate('archiveWalletConfirmMessage')
          : this.transloco.translate('archiveWalletConfirmMessageWithBalance', { balance }),
      confirmLabel: this.transloco.translate('archiveWalletAction'),
      destructive: true,
    });
    if (!confirmed) return;
    this.archiving.set(true);
    try {
      await this.walletsApi.archive(wallet.id, wallet.version);
      await this.router.navigateByUrl('/app/account/wallets');
    } catch (error) {
      this.errors.fromError(error);
    } finally {
      this.archiving.set(false);
    }
  }
}
