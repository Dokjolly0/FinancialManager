import 'package:flutter/material.dart';

/// Maps each backend-validated icon key (wallets.ValidIcons) to the
/// Material icon shown for it. Kept as a single source of truth so the
/// picker grid and every wallet tile/card render the same glyph for a
/// given key.
const Map<String, IconData> walletIconData = {
  'wallet': Icons.account_balance_wallet,
  'cash': Icons.payments,
  'bank': Icons.account_balance,
  'card': Icons.credit_card,
  'piggy_bank': Icons.savings,
  'safe': Icons.lock,
  'coins': Icons.monetization_on,
  'briefcase': Icons.work,
  'gift': Icons.card_giftcard,
  'shopping_bag': Icons.shopping_bag,
  'home': Icons.home,
  'savings': Icons.savings_outlined,
  'restaurant': Icons.restaurant,
};

IconData iconForWalletKey(String key) =>
    walletIconData[key] ?? Icons.account_balance_wallet;

/// Fixed color palette wallets may pick from — the same "pick from a
/// small curated set" pattern as the registration avatar picker
/// (register_screen.dart's `_avatarColorChoices`), just a larger palette
/// since wallets are more numerous/longer-lived than an avatar.
const List<Color> walletColorChoices = [
  Color(0xFF6750A4),
  Color(0xFF176B5B),
  Color(0xFF175CD3),
  Color(0xFFB54708),
  Color(0xFFB42318),
  Color(0xFF6941C6),
  Color(0xFF0E7490),
  Color(0xFF3F6212),
  Color(0xFFA21CAF),
  Color(0xFF334155),
];
