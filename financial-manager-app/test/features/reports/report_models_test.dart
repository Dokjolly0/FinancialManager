import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/reports/domain/models/report_breakdown.dart';
import 'package:financialmanager/features/reports/domain/models/report_monthly_comparison.dart';
import 'package:financialmanager/features/reports/domain/models/report_period.dart';
import 'package:financialmanager/features/reports/domain/models/report_summary.dart';
import 'package:financialmanager/features/reports/domain/models/report_timeseries.dart';

void main() {
  test('ReportSummary.fromJson parses the backend shape', () {
    final summary = ReportSummary.fromJson({
      'opening_balance_minor': 1000,
      'closing_balance_minor': 1500,
      'total_credits_minor': 800,
      'total_debits_minor': 300,
      'net_minor': 500,
      'savings_rate_percent': 62.5,
      'transaction_count': 3,
      'currency': 'EUR',
      'to': '2026-07-19T00:00:00Z',
    });
    expect(summary.openingBalance.minorUnits, 1000);
    expect(summary.closingBalance.minorUnits, 1500);
    expect(summary.savingsRatePercent, 62.5);
    expect(summary.transactionCount, 3);
  });

  test(
    'ReportSummary.fromJson leaves savingsRatePercent null when omitted',
    () {
      final summary = ReportSummary.fromJson({
        'opening_balance_minor': 0,
        'closing_balance_minor': 0,
        'total_credits_minor': 0,
        'total_debits_minor': 0,
        'net_minor': 0,
        'transaction_count': 0,
        'currency': 'EUR',
        'to': '2026-07-19T00:00:00Z',
      });
      expect(summary.savingsRatePercent, isNull);
    },
  );

  test('ReportTimeseries.fromJson parses points and granularity', () {
    final timeseries = ReportTimeseries.fromJson({
      'granularity': 'monthly',
      'points': [
        {
          'period_start': '2026-06-01T00:00:00Z',
          'credits_minor': 100,
          'debits_minor': 40,
          'net_minor': 60,
          'balance_minor': 560,
        },
      ],
    }, currency: 'EUR');
    expect(timeseries.isMonthly, isTrue);
    expect(timeseries.points, hasLength(1));
    expect(timeseries.points.first.balance.minorUnits, 560);
  });

  test('ReportBreakdown.fromJson keeps credits and debits separate', () {
    final breakdown = ReportBreakdown.fromJson({
      'group_by': 'category',
      'credits': [
        {
          'key': 'salary',
          'label': 'Stipendio',
          'amount_minor': 100000,
          'percentage': 100.0,
          'transaction_count': 1,
        },
      ],
      'debits': [
        {
          'key': 'other',
          'label': 'Altre',
          'amount_minor': 500,
          'percentage': 10.0,
          'transaction_count': 4,
        },
      ],
    }, currency: 'EUR');
    expect(breakdown.credits, hasLength(1));
    expect(breakdown.debits, hasLength(1));
    expect(breakdown.debits.first.isOther, isTrue);
    expect(breakdown.credits.first.isOther, isFalse);
  });

  test('ReportMonthlyComparison.fromJson parses months and the span flag', () {
    final comparison = ReportMonthlyComparison.fromJson({
      'spans_multiple_months': true,
      'months': [
        {
          'month': '2026-06-01T00:00:00Z',
          'credits_minor': 100,
          'debits_minor': 40,
          'net_minor': 60,
        },
      ],
    }, currency: 'EUR');
    expect(comparison.spansMultipleMonths, isTrue);
    expect(comparison.months, hasLength(1));
    expect(comparison.months.first.net.minorUnits, 60);
  });

  test('ReportPreset round-trips through the API string', () {
    for (final preset in ReportPreset.values) {
      final api = preset.toApi();
      expect(api, isNotEmpty);
      expect(preset.label, isNotEmpty);
    }
  });
}
