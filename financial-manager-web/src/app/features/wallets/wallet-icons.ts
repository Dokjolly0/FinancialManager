import type { IconNode } from 'lucide';
import {
  BriefcaseBusiness,
  Coins,
  CreditCard,
  Gift,
  HandCoins,
  House,
  Landmark,
  Lock,
  PiggyBank,
  ShoppingBag,
  Utensils,
  Vault,
  Wallet,
} from 'lucide';

/**
 * Glyph for each wallet icon key, one map for the picker and every wallet
 * row (the app's walletIconData, Lucide instead of Material icons).
 */
export const WALLET_ICONS: Record<string, IconNode> = {
  wallet: Wallet,
  cash: HandCoins,
  bank: Landmark,
  card: CreditCard,
  piggy_bank: PiggyBank,
  safe: Lock,
  coins: Coins,
  briefcase: BriefcaseBusiness,
  gift: Gift,
  shopping_bag: ShoppingBag,
  home: House,
  savings: Vault,
  restaurant: Utensils,
};

export const walletIcon = (key: string): IconNode => WALLET_ICONS[key] ?? Wallet;
