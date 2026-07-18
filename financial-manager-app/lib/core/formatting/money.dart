import 'package:intl/intl.dart';

/// Monetary amount in minor units (cents) plus an ISO-4217 currency code
/// (plan.md section 9.7 / 4.3). Amounts are never represented as
/// floating-point — every arithmetic operation here works on the integer
/// [minorUnits], and the wire format is `{"amount_minor": 1234, "currency":
/// "EUR"}`, matching the backend contract.
class Money {
  const Money({required this.minorUnits, required this.currency});

  /// Amount in the currency's smallest unit, e.g. cents for EUR.
  /// `€12,34` is `minorUnits: 1234`.
  final int minorUnits;

  /// ISO-4217 currency code, e.g. "EUR".
  final String currency;

  static const zeroEur = Money(minorUnits: 0, currency: 'EUR');

  bool get isNegative => minorUnits < 0;
  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  Money operator -() => Money(minorUnits: -minorUnits, currency: currency);

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Cannot combine Money in different currencies: $currency vs ${other.currency}',
      );
    }
  }

  /// Formats using the given [locale] (defaults to `it_IT`), e.g. "€ 2.430,50".
  String format({String locale = 'it_IT'}) {
    final format = NumberFormat.simpleCurrency(locale: locale, name: currency);
    return format.format(minorUnits / 100);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits $currency)';
}
