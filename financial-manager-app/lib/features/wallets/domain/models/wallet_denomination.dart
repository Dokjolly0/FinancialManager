/// One banknote/coin row of a CASH wallet's denomination breakdown
/// (migration 0022's wallet_cash_denominations). Purely informational —
/// never reconciled against the wallet's actual current_balance_minor.
/// [enabled] lets a user hide denominations they never handle (e.g. 1/2
/// cent coins) from the editor without losing a previously counted value.
class WalletDenomination {
  const WalletDenomination({
    required this.denominationMinor,
    required this.count,
    required this.enabled,
  });

  final int denominationMinor;
  final int count;
  final bool enabled;

  WalletDenomination copyWith({int? count, bool? enabled}) {
    return WalletDenomination(
      denominationMinor: denominationMinor,
      count: count ?? this.count,
      enabled: enabled ?? this.enabled,
    );
  }

  static WalletDenomination fromJson(Map<String, dynamic> json) {
    return WalletDenomination(
      denominationMinor: json['denomination_minor'] as int,
      count: json['count'] as int,
      enabled: json['enabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'denomination_minor': denominationMinor,
    'count': count,
    'enabled': enabled,
  };
}
