import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/transactions/domain/models/payment_group_summary.dart';

void main() {
  group('PaymentGroupSummary.fromJson', () {
    test('parses every field, including the signed net amount', () {
      final summary = PaymentGroupSummary.fromJson({
        'payment_group_id': 'group-1',
        'member_count': 2,
        'net_amount_minor': -40000,
        'currency': 'EUR',
        'representative_transaction_id': 'tx-1',
        'representative_title': 'Acconto viaggio',
      });

      expect(summary.paymentGroupId, 'group-1');
      expect(summary.memberCount, 2);
      expect(summary.netAmount.minorUnits, -40000);
      expect(summary.netAmount.currency, 'EUR');
      expect(summary.representativeTransactionId, 'tx-1');
      expect(summary.representativeTitle, 'Acconto viaggio');
    });
  });
}
