import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/formatting/money.dart';

void main() {
  group('Money', () {
    test('adds and subtracts within the same currency', () {
      const a = Money(minorUnits: 1000, currency: 'EUR');
      const b = Money(minorUnits: 250, currency: 'EUR');

      expect((a + b).minorUnits, 1250);
      expect((a - b).minorUnits, 750);
    });

    test('throws when combining different currencies', () {
      const eur = Money(minorUnits: 100, currency: 'EUR');
      const usd = Money(minorUnits: 100, currency: 'USD');

      expect(() => eur + usd, throwsArgumentError);
    });

    test('sign helpers reflect minorUnits', () {
      expect(const Money(minorUnits: -1, currency: 'EUR').isNegative, isTrue);
      expect(const Money(minorUnits: 0, currency: 'EUR').isZero, isTrue);
      expect(const Money(minorUnits: 1, currency: 'EUR').isPositive, isTrue);
    });

    test('formats 1234 minor units as 12,34', () {
      const amount = Money(minorUnits: 1234, currency: 'EUR');
      expect(amount.format(locale: 'it_IT'), contains('12,34'));
    });

    test('equality is based on minorUnits and currency', () {
      expect(
        const Money(minorUnits: 500, currency: 'EUR'),
        const Money(minorUnits: 500, currency: 'EUR'),
      );
      expect(
        const Money(minorUnits: 500, currency: 'EUR'),
        isNot(const Money(minorUnits: 500, currency: 'USD')),
      );
    });
  });
}
