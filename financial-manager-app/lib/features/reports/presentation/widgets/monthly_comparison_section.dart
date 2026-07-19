import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/report_monthly_comparison.dart';

/// Confronto mensile (plan.md section 7.12, 18.7, 18.8): only rendered
/// when the period spans more than one calendar month — the caller checks
/// [ReportMonthlyComparison.spansMultipleMonths] before building this
/// widget. Bars affiancate entrate/uscite, tap for detail, and an
/// always-visible table underneath (plan.md: "tabella accessibile sotto il
/// grafico").
class MonthlyComparisonSection extends StatelessWidget {
  const MonthlyComparisonSection({super.key, required this.comparison});

  final ReportMonthlyComparison comparison;

  void _showMonthDetail(BuildContext context, MonthlyComparisonRow row) {
    final label = DateFormat('MMMM yyyy', 'it_IT').format(row.month.toLocal());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${label[0].toUpperCase()}${label.substring(1)}: '
          'entrate ${row.credits.format()}, uscite ${row.debits.format()}, '
          'netto ${row.net.format()}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final months = comparison.months;
    final maxValue = months.fold<int>(0, (max, m) {
      final v = m.credits.minorUnits > m.debits.minorUnits
          ? m.credits.minorUnits
          : m.debits.minorUnits;
      return v > max ? v : max;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confronto mensile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (months.isEmpty)
              const Text('Nessun dato per il periodo selezionato.')
            else
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: maxValue == 0 ? 1 : maxValue / 100 * 1.1,
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 || index >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat(
                                  'MMM',
                                  'it_IT',
                                ).format(months[index].month.toLocal()),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions) return;
                        final index = response?.spot?.touchedBarGroupIndex;
                        if (index == null || index < 0 || index >= months.length) {
                          return;
                        }
                        _showMonthDetail(context, months[index]);
                      },
                    ),
                    barGroups: [
                      for (var i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: months[i].credits.minorUnits / 100,
                              color: colorScheme.primary,
                              width: 8,
                            ),
                            BarChartRodData(
                              toY: months[i].debits.minorUnits / 100,
                              color: colorScheme.error,
                              width: 8,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Mese')),
                  DataColumn(label: Text('Entrate'), numeric: true),
                  DataColumn(label: Text('Uscite'), numeric: true),
                  DataColumn(label: Text('Netto'), numeric: true),
                ],
                rows: [
                  for (final row in months)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            DateFormat(
                              'MMM yyyy',
                              'it_IT',
                            ).format(row.month.toLocal()),
                          ),
                        ),
                        DataCell(Text(row.credits.format())),
                        DataCell(Text(row.debits.format())),
                        DataCell(Text(row.net.format())),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
