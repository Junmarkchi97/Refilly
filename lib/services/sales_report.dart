/// A sales period with every day filled in, including days that had no orders.
class SalesReport {
  final String stationName;
  final String rangeLabel;
  final DateTime from;
  final DateTime to;
  final List<SalesDay> days;
  final List<SalesProduct> products;

  const SalesReport({
    required this.stationName,
    required this.rangeLabel,
    required this.from,
    required this.to,
    required this.days,
    required this.products,
  });

  double get revenue => days.fold(0, (sum, day) => sum + day.revenue);
  int get orders => days.fold(0, (sum, day) => sum + day.orders);
  int get daysWithSales => days.where((day) => day.revenue > 0 || day.orders > 0).length;
  double get bestDay => days.fold(0, (best, day) => day.revenue > best ? day.revenue : best);
  double get averageOrder => orders == 0 ? 0 : revenue / orders;

  String get fileSlug {
    final station = stationName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final range = rangeLabel.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final who = station.isEmpty ? 'station' : station;
    return 'refilly-sales-$who-$range';
  }
}

class SalesDay {
  final DateTime date;
  final int orders;
  final double revenue;
  const SalesDay({required this.date, required this.orders, required this.revenue});
}

class SalesProduct {
  final String name;
  final int quantity;
  final double revenue;
  const SalesProduct({required this.name, required this.quantity, required this.revenue});
}

SalesReport buildSalesReport({
  required String stationName,
  required String rangeLabel,
  required DateTime from,
  required DateTime to,
  required List<Map<String, dynamic>> dayRows,
  required List<Map<String, dynamic>> productRows,
}) {
  final byDay = <String, Map<String, dynamic>>{};
  for (final row in dayRows) {
    final key = _dayKey(row['day']);
    if (key != null) byDay[key] = row;
  }
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  final count = end.difference(start).inDays;
  final days = [
    for (var i = 0; i < count; i++)
      SalesDay(
        date: start.add(Duration(days: i)),
        orders: (byDay[_ymd(start.add(Duration(days: i)))]?['orders'] as num?)?.toInt() ?? 0,
        revenue: (byDay[_ymd(start.add(Duration(days: i)))]?['revenue'] as num?)?.toDouble() ?? 0,
      ),
  ];
  final products = [
    for (final row in productRows)
      SalesProduct(
        name: '${row['product_name'] ?? ''}',
        quantity: (row['qty'] as num?)?.toInt() ?? 0,
        revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
      ),
  ];
  return SalesReport(
    stationName: stationName,
    rangeLabel: rangeLabel,
    from: start,
    to: end.subtract(const Duration(days: 1)),
    days: days,
    products: products,
  );
}

/// UTF-8 CSV that Excel opens with amounts as numbers, in PHP.
String salesReportCsv(SalesReport report) {
  final lines = <String>[
    _row(['Station', report.stationName]),
    _row(['Period', report.rangeLabel]),
    _row(['From', _ymd(report.from)]),
    _row(['To', _ymd(report.to)]),
    _row(['Currency', 'PHP']),
    _row(['Revenue', report.revenue.toStringAsFixed(2)]),
    _row(['Orders', report.orders]),
    _row(['Average order', report.averageOrder.toStringAsFixed(2)]),
    _row(['Best day', report.bestDay.toStringAsFixed(2)]),
    _row(['Days with sales', '${report.daysWithSales} of ${report.days.length}']),
    '',
    _row(['Date', 'Orders', 'Revenue']),
    for (final day in report.days) _row([_ymd(day.date), day.orders, day.revenue.toStringAsFixed(2)]),
    '',
    _row(['Product', 'Quantity sold', 'Revenue']),
    for (final product in report.products) _row([product.name, product.quantity, product.revenue.toStringAsFixed(2)]),
  ];
  return lines.join('\n');
}

String _row(List<Object?> cells) => cells.map(_cell).join(',');

String _cell(Object? value) {
  final text = '${value ?? ''}';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String? _dayKey(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return _ymd(value);
  final text = value.toString();
  return text.length >= 10 ? text.substring(0, 10) : null;
}

String _ymd(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
