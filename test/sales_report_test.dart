import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/services/sales_pdf.dart';
import 'package:refilly/services/sales_report.dart';
import 'package:refilly/theme.dart';

void main() {
  SalesReport sample() => buildSalesReport(
    stationName: 'AquaPure Refilling - Cubao',
    rangeLabel: 'Today',
    from: DateTime(2026, 11, 3),
    to: DateTime(2026, 11, 4),
    dayRows: [
      {'day': '2026-11-03', 'orders': 2, 'revenue': 75},
    ],
    productRows: [
      {'product_name': 'Purified Water, 5 gal', 'qty': 2, 'revenue': 60},
    ],
  );

  test('csv includes every day and escapes product names for Excel', () {
    final csv = salesReportCsv(sample());
    expect(csv, contains('AquaPure Refilling - Cubao'));
    expect(csv, contains('Currency,PHP'));
    expect(csv, contains('2026-11-03,2,75.00'));
    expect(csv, contains('"Purified Water, 5 gal",2,60.00'));
    expect(csv, contains('Days with sales,1 of 1'));
    expect(sample().fileSlug, 'refilly-sales-aquapure-refilling-cubao-today');
  });

  test('a quiet day is still listed', () {
    final report = buildSalesReport(
      stationName: 'Station',
      rangeLabel: '7 days',
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 3),
      dayRows: const [],
      productRows: const [],
    );
    expect(report.days, hasLength(2));
    expect(report.orders, 0);
    expect(report.revenue, 0);
  });

  test('pdf starts as a real document', () async {
    final bytes = await salesReportPdf(sample());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('cards use a neutral edge instead of a blue shadow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: const Scaffold(body: AppCard(child: Text('Revenue'))),
    ));
    final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).firstWhere((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration && decoration.boxShadow != null;
    });
    final shadow = (decorated.decoration as BoxDecoration).boxShadow!.single;
    expect(shadow.color, const Color(0xFF171717).withValues(alpha: .06));
    expect(shadow.color, isNot(const Color(0xFF1A4B7A).withValues(alpha: .08)));
  });
}
