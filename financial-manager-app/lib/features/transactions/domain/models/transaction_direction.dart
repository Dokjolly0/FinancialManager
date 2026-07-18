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
/// [openingBalance] and [balanceAdjustment] are created by dedicated flows
/// (registration, balance adjustment) and shown read-only elsewhere.
enum TransactionKind {
  standard,
  openingBalance,
  balanceAdjustment,
  unknown;

  static TransactionKind fromApi(String value) => switch (value) {
    'STANDARD' => TransactionKind.standard,
    'OPENING_BALANCE' => TransactionKind.openingBalance,
    'BALANCE_ADJUSTMENT' => TransactionKind.balanceAdjustment,
    _ => TransactionKind.unknown,
  };
}
