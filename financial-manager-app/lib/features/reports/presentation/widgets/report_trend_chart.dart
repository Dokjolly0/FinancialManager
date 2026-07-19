import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/report_timeseries.dart';

/// Grafico andamento (plan.md section 7.12): cumulative balance line at
/// the backend's chosen granularity. A table view is offered alongside the
/// chart (plan.md Fase 7 "accessibilità e tabella alternativa") since a
/// canvas-drawn line chart carries no information to a screen reader.
class ReportTrendChart extends StatefulWidget {
  const ReportTrendChart({super.key, required this.timeseries});

  final ReportTimeseries timeseries;

  @override
  State<ReportTrendChart> createState() => _ReportTrendChartState();
}

class _ReportTrendChartState extends State<ReportTrendChart> {
  bool _showTable = false;

  String _formatDate(DateTime d) {
    final pattern = widget.timeseries.isMonthly ? 'MMM yyyy' : 'd MMM';
    return DateFormat(pattern, 'it_IT').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.timeseries.points;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Andamento',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: Icon(_showTable ? Icons.show_chart : Icons.table_rows),
                  tooltip: _showTable
                      ? 'Mostra grafico'
                      : 'Mostra tabella (accessibile)',
                  onPressed: () => setState(() => _showTable = !_showTable),
                ),
              ],
            ),
            if (points.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('Nessun dato per il periodo selezionato.'),
              )
            else if (_showTable)
              _TrendTable(points: points, formatDate: _formatDate)
            else
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: (points.length / 4).clamp(1, points.length).toDouble(),
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _formatDate(points[index].periodStart),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].balance.minorUnits / 100),
                        ],
                        isCurved: true,
                        color: colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points, required this.formatDate});

  final List<TimeseriesPoint> points;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Periodo')),
          DataColumn(label: Text('Entrate'), numeric: true),
          DataColumn(label: Text('Uscite'), numeric: true),
          DataColumn(label: Text('Saldo'), numeric: true),
        ],
        rows: [
          for (final p in points)
            DataRow(
              cells: [
                DataCell(Text(formatDate(p.periodStart))),
                DataCell(Text(p.credits.format())),
                DataCell(Text(p.debits.format())),
                DataCell(Text(p.balance.format())),
              ],
            ),
        ],
      ),
    );
  }
}
