import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/sales_pdf.dart';
import '../../services/sales_report.dart';
import '../../theme.dart';
import '../network_states.dart';
import '../widgets.dart';

class SalesScreen extends StatefulWidget {
  final Station station;
  const SalesScreen({super.key, required this.station});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _range = 'week';
  late Future<_Data> _f = _load();

  (DateTime, DateTime) get _bounds {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 1));
    return switch (_range) {
      'day' => (today, end),
      'week' => (today.subtract(const Duration(days: 6)), end),
      _ => (today.subtract(const Duration(days: 29)), end),
    };
  }

  Future<_Data> _load() async {
    final (from, to) = _bounds;
    final days = await Api.sales(widget.station.id, from, to);
    final top = await Api.topProducts(widget.station.id, from, to);
    return _Data(from, to, days, top);
  }

  Future<void> _export(SalesReport report, {required bool pdf}) async {
    try {
      final bytes = pdf ? await salesReportPdf(report) : utf8.encode('\uFEFF${salesReportCsv(report)}');
      final name = '${report.fileSlug}.${pdf ? 'pdf' : 'csv'}';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: pdf ? 'application/pdf' : 'text/csv',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          subject: '${report.stationName} sales',
        ),
      );
    } catch (e) {
      if (!mounted || e.toString().toLowerCase().contains('cancel')) return;
      showFailureNotice(context, e, failed: 'Could not export this report.');
    }
  }

  void _chooseExport(SalesReport report) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Export this period', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV for Excel'),
              subtitle: const Text('Daily sales and top products'),
              onTap: () {
                Navigator.pop(sheet);
                _export(report, pdf: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('A summary you can share or print'),
              onTap: () {
                Navigator.pop(sheet);
                _export(report, pdf: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolbar({SalesReport? report}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Column(
      children: [
        _PeriodSwitch(
          value: _range,
          onChanged: (value) => setState(() {
            _range = value;
            _f = _load();
          }),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: report == null ? null : () => _chooseExport(report),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export'),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    clipBehavior: Clip.none,
    padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset(context, 100)),
    children: [
      FutureBuilder<_Data>(
        future: _f,
        builder: (context, snap) => StateSwitcher(
          child: KeyedSubtree(
            key: ValueKey(snap.hasData),
            child: Builder(
              builder: (context) {
                if (snap.hasError) {
                  return Column(
                    children: [
                      _toolbar(),
                      SizedBox(
                        height: 360,
                        child: LoadFailureView(error: snap.error!, onRetry: () => setState(() => _f = _load()), compact: true),
                      ),
                    ],
                  );
                }
                if (!snap.hasData) {
                  return Column(
                    children: [
                      _toolbar(),
                      const SizedBox(height: 420, child: SkeletonList(count: 4, height: 96)),
                    ],
                  );
                }
                final d = snap.data!;
                final report = buildSalesReport(
                  stationName: widget.station.name,
                  rangeLabel: switch (_range) {
                    'day' => 'Today',
                    'week' => '7 days',
                    _ => '30 days',
                  },
                  from: d.from,
                  to: d.to,
                  dayRows: d.days,
                  productRows: d.top,
                );
                final best = report.bestDay;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _toolbar(report: report),
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedCount(
                                    value: report.revenue,
                                    format: peso,
                                    style: Theme.of(context).textTheme.headlineMedium,
                                  ),
                                ),
                                const Text(
                                  'Revenue',
                                  style: TextStyle(color: RF.muted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${report.daysWithSales} of ${report.days.length} days with sales',
                                  style: const TextStyle(fontSize: 13, color: RF.muted),
                                ),
                              ],
                            ),
                          ),
                          Ring(
                            value: report.days.isEmpty ? 0 : report.daysWithSales / report.days.length,
                            size: 104,
                            color: RF.accent,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedCount(
                                  value: report.orders.toDouble(),
                                  format: (v) => v.round().toString(),
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const Text('orders', style: TextStyle(fontSize: 11, color: RF.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatTile(label: 'Delivered', value: '${report.orders}', icon: Icons.check_rounded, tint: const Color(0xFF1DB954)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              label: 'Avg order',
                              value: peso(report.averageOrder),
                              icon: Icons.receipt_rounded,
                              tint: RF.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(label: 'Best day', value: peso(best), icon: Icons.bolt_rounded, tint: const Color(0xFFE8890C)),
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: DailyRevenueChart(days: report.days),
                    ),
                    const SectionTitle('Top products'),
                    if (d.top.isEmpty)
                      const EmptyState(
                        icon: Icons.bar_chart_rounded,
                        title: 'No sales yet',
                        subtitle: 'Delivered orders in this period will show up here.',
                      ),
                    for (final (tIdx, t) in (d.top).indexed)
                      FadeSlideIn(
                        index: tIdx,
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['product_name'], style: Theme.of(context).textTheme.titleMedium),
                                    Text('${t['qty']} sold', style: const TextStyle(color: RF.muted)),
                                  ],
                                ),
                              ),
                              Text(peso(t['revenue'] as num), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

class DailyRevenueChart extends StatelessWidget {
  final List<SalesDay> days;
  const DailyRevenueChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Text('Daily revenue', style: Theme.of(context).textTheme.titleMedium);
    }
    final peak = days.fold<double>(0, (best, day) => math.max(best, day.revenue));
    final step = _chartStep(peak <= 0 ? 4 : peak);
    final maxY = math.max(step * 2, (peak / step).ceil() * step + step);
    final xInterval = days.length <= 7 ? 1.0 : days.length <= 14 ? 2.0 : 5.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily revenue', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: math.max(0, days.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE6E6E8), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: step,
                    getTitlesWidget: (value, _) => Text(
                      _axisMoney(value),
                      style: const TextStyle(color: RF.muted, fontSize: 11),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: xInterval,
                    getTitlesWidget: (value, _) {
                      final index = value.round();
                      if ((value - index).abs() > 0.01 || index < 0 || index >= days.length) {
                        return const SizedBox.shrink();
                      }
                      final date = days[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${date.month}/${date.day}', style: const TextStyle(color: RF.muted, fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBorderRadius: BorderRadius.circular(10),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => RF.ink,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final index = spot.x.round();
                    if (index < 0 || index >= days.length) return null;
                    final day = days[index];
                    return LineTooltipItem(
                      '${day.date.month}/${day.date.day}\n${peso(day.revenue)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.3),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].revenue)],
                  isCurved: false,
                  color: RF.ink,
                  barWidth: 2.4,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) => spot.y > 0,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: 4,
                      color: RF.ink,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(show: true, color: RF.ink.withValues(alpha: .08)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

double _chartStep(double peak) {
  final raw = math.max(peak / 4, 1);
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final fraction = raw / magnitude;
  final nice = fraction <= 1 ? 1 : fraction <= 2 ? 2 : fraction <= 5 ? 5 : 10;
  return nice * magnitude;
}

String _axisMoney(double value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
  }
  return value.round().toString();
}

class _PeriodSwitch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [('day', 'Today'), ('week', '7 days'), ('month', '30 days')];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E6E8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Material(
                  color: value == item.$1 ? RF.button : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(item.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        item.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: value == item.$1 ? Colors.white : RF.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Data {
  final DateTime from, to;
  final List<Map<String, dynamic>> days, top;
  _Data(this.from, this.to, this.days, this.top);
}
