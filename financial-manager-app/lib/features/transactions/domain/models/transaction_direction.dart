/// Economic direction of a transaction (plan.md section 4.2): whether it
/// increases or decreases the wallet balance. Kept distinct from the sign
/// of the amount — amounts are always positive (section 4.3); direction is
/// what determines the effect.
enum TransactionDirection {
  credit,
  debit;

  static TransactionDirection fromApi(String value) => switch (value) {
    'CREDIT' => TransactionDirection.credit,
    'DEBIT' => TransactionDirection.debit,
    _ => throw ArgumentError('Unknown transaction direction: $value'),
  };

  String toApi() => switch (this) {
    TransactionDirection.credit => 'CREDIT',
    TransactionDirection.debit => 'DEBIT',
  };

  bool get isCredit => this == TransactionDirection.credit;
}

/// Technical nature of a transaction (plan.md section 4.2). Only
/// [standard] can be created/edited/deleted through the ordinary UI;
/// [openingBalance] additionally allows editing its amount and date (to fix
/// a wrong initial balance) through a dedicated flow, but never deletion.
/// [balanceAdjustment] and [transfer] are created by dedicated flows
/// (balance adjustment, wallet-to-wallet transfer) and always shown
/// read-only. [transfer] rows are excluded from expense/income report
/// totals by construction (the backend never queries them there).
enum TransactionKind {
  standard,
  openingBalance,
  balanceAdjustment,
  transfer,
  unknown;

  static TransactionKind fromApi(String value) => switch (value) {
    'STANDARD' => TransactionKind.standard,
    'OPENING_BALANCE' => TransactionKind.openingBalance,
    'BALANCE_ADJUSTMENT' => TransactionKind.balanceAdjustment,
    'TRANSFER' => TransactionKind.transfer,
    _ => TransactionKind.unknown,
  };
}
