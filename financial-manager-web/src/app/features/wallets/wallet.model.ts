/** A wallet as GET /v1/wallets returns it (archived wallets are not listed). */
export interface Wallet {
  id: string;
  name: string;
  type: WalletType;
  icon: string;
  color: string;
  current_balance_minor: number;
  currency: string;
  version: number;
  updated_at: string;
  archived_at?: string | null;
  /** What the wallet is for, read by the AI analysis (plan.md section 32.3). */
  purpose?: string | null;
  /** MEAL_VOUCHER only: face value of one voucher, fixed at creation. */
  voucher_unit_value_minor?: number | null;
  /**
   * Expiry policy (backend wallets.ComputeLotExpiry): vouchers loaded in a
   * month up to the cutoff expire on month/day of the same year, later ones
   * of the following year.
   */
  voucher_expiry_cutoff_month?: number | null;
  voucher_expiry_month?: number | null;
  voucher_expiry_day?: number | null;
  /** Active lots expiring within 30 days (list and get only). */
  voucher_expiring_soon_count?: number | null;
}

export type WalletType = 'CASH' | 'BANK' | 'MEAL_VOUCHER' | 'OTHER';

export const WALLET_TYPES: WalletType[] = ['BANK', 'CASH', 'MEAL_VOUCHER', 'OTHER'];

/** One banknote or coin row of a cash wallet (informational, never reconciled). */
export interface WalletDenomination {
  denomination_minor: number;
  count: number;
  enabled: boolean;
}

/** A batch of meal vouchers loaded in one operation, consumed FIFO by expiry. */
export interface VoucherLot {
  id: string;
  quantity_total: number;
  quantity_remaining: number;
  quantity_expired: number;
  expires_at: string;
  created_by_transaction_id: string;
  expired_by_transaction_id?: string | null;
  created_at: string;
}

/** The backend's 30-day "expiring soon" window, mirrored by hand (not in the API). */
export const VOUCHER_EXPIRING_SOON_DAYS = 30;

/** Icon keys the backend accepts (wallets.ValidIcons). */
export const WALLET_ICON_KEYS = [
  'wallet',
  'cash',
  'bank',
  'card',
  'piggy_bank',
  'safe',
  'coins',
  'briefcase',
  'gift',
  'shopping_bag',
  'home',
  'savings',
  'restaurant',
] as const;

/** The curated colours a wallet may pick (the app's walletColorChoices). */
export const WALLET_COLORS = [
  '#6750A4',
  '#176B5B',
  '#175CD3',
  '#B54708',
  '#B42318',
  '#6941C6',
  '#0E7490',
  '#3F6212',
  '#A21CAF',
  '#334155',
];

export const DEFAULT_WALLET_ICON = 'wallet';
export const DEFAULT_WALLET_COLOR = '#6750A4';
/** backend wallets.MaxPurposeLength */
export const WALLET_PURPOSE_MAX_LENGTH = 280;
/** Vouchers loaded January-August expire Dec 31 that year; later ones, the next year. */
export const DEFAULT_VOUCHER_EXPIRY = { cutoffMonth: 8, month: 12, day: 31 };

export const isMealVoucher = (wallet: Wallet) => wallet.type === 'MEAL_VOUCHER';
