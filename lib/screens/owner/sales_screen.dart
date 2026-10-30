import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../../theme.dart';
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'day', label: Text('Today')),
            ButtonSegment(value: 'week', label: Text('7 days')),
            ButtonSegment(value: 'month', label: Text('30 days')),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() {
            _range = s.first;
            _f = _load();
          }),
        ),
      ),
      FutureBuilder<_Data>(
        future: _f,
        builder: (context, snap) => StateSwitcher(
          child: KeyedSubtree(
            key: ValueKey(snap.hasData),
            child: Builder(
              builder: (context) {
                if (snap.hasError) return Text('${snap.error}');
                if (!snap.hasData) {
                  return const SizedBox(height: 420, child: SkeletonList(count: 4, height: 96));
                }
                final d = snap.data!;
                final revenue = d.days.fold<double>(0, (t, r) => t + (r['revenue'] as num).toDouble());
                final orders = d.days.fold<int>(0, (t, r) => t + (r['orders'] as num).toInt());
                final byDay = {for (final r in d.days) r['day'] as String: (r['revenue'] as num).toDouble()};
                final n = d.to.difference(d.from).inDays;
                final series = [for (var i = 0; i < n; i++) byDay[d.from.add(Duration(days: i)).toIso8601String().substring(0, 10)] ?? 0.0];
                final best = series.fold<double>(0, (a, b) => b > a ? b : a);
                final activeDays = series.where((v) => v > 0).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedCount(value: revenue, format: peso, style: Theme.of(context).textTheme.headlineLarge),
                                const Text(
                                  'Revenue',
                                  style: TextStyle(color: RF.muted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Text('$activeDays of $n days with sales', style: const TextStyle(fontSize: 13, color: RF.muted)),
                              ],
                            ),
                          ),
                          Ring(
                            value: n == 0 ? 0 : activeDays / n,
                            size: 104,
                            color: RF.accent,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedCount(
                                  value: orders.toDouble(),
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
                            child: StatTile(label: 'Delivered', value: '$orders', icon: Icons.check_rounded, tint: const Color(0xFF1DB954)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              label: 'Avg order',
                              value: orders == 0 ? peso(0) : peso(revenue / orders),
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

class _Data {
  final DateTime from, to;
  final List<Map<String, dynamic>> days, top;
  _Data(this.from, this.to, this.days, this.top);
}
