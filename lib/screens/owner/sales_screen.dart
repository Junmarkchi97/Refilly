import 'dart:convert';

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
                final series = [for (final day in report.days) day.revenue];
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
                                AnimatedCount(value: report.revenue, format: peso, style: Theme.of(context).textTheme.headlineLarge),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily revenue', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(
                                  topTitles: AxisTitles(),
                                  rightTitles: AxisTitles(),
                                  leftTitles: AxisTitles(),
                                  bottomTitles: AxisTitles(),
                                ),
                                barGroups: [
                                  for (var i = 0; i < series.length; i++)
                                    BarChartGroupData(
                                      x: i + 1,
                                      barRods: [
                                        BarChartRodData(
                                          toY: series[i],
                                          width: series.length > 10 ? 6 : 18,
                                          color: i == series.length - 1 ? RF.accent : RF.ink,
                                          borderRadius: BorderRadius.circular(8),
                                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: best == 0 ? 1 : best, color: RF.bg),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
