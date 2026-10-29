import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api.dart';
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
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
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
        const SizedBox(height: 16),
        FutureBuilder<_Data>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}');
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final d = snap.data!;
            final revenue = d.days.fold<double>(0, (t, r) => t + (r['revenue'] as num).toDouble());
            final orders = d.days.fold<int>(0, (t, r) => t + (r['orders'] as num).toInt());
            // fill missing days with zero
            final byDay = {for (final r in d.days) r['day'] as String: (r['revenue'] as num).toDouble()};
            final n = d.to.difference(d.from).inDays;
            final series = [
              for (var i = 0; i < n; i++)
                byDay[d.from.add(Duration(days: i)).toIso8601String().substring(0, 10)] ?? 0.0,
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _stat('Revenue', peso(revenue)),
                _stat('Delivered orders', '$orders'),
                _stat('Avg order', orders == 0 ? peso(0) : peso(revenue / orders)),
              ]),
              const SizedBox(height: 24),
              Text('Daily revenue', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(topTitles: AxisTitles(), rightTitles: AxisTitles()),
                  barGroups: [
                    for (var i = 0; i < series.length; i++)
                      BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: series[i], color: Theme.of(context).colorScheme.primary)]),
                  ],
                )),
              ),
              const SizedBox(height: 24),
              Text('Top products', style: Theme.of(context).textTheme.titleMedium),
              if (d.top.isEmpty) const Text('No delivered orders in this period'),
              for (final t in d.top)
                ListTile(dense: true, title: Text(t['product_name']), subtitle: Text('${t['qty']} sold'), trailing: Text(peso(t['revenue'] as num))),
            ]);
          },
        ),
      ]);

  Widget _stat(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ]),
        ),
      );
}

class _Data {
  final DateTime from, to;
  final List<Map<String, dynamic>> days, top;
  _Data(this.from, this.to, this.days, this.top);
}
