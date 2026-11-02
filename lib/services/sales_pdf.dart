import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'sales_report.dart';

Future<Uint8List> salesReportPdf(SalesReport report) async {
  final doc = pw.Document();
  String money(num value) => 'PHP ${value.toStringAsFixed(2)}';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Text('Refilly sales', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(_plain(report.stationName), style: const pw.TextStyle(fontSize: 14)),
        pw.Text('${_plain(report.rangeLabel)} | ${_ymd(report.from)} to ${_ymd(report.to)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Revenue', 'Orders', 'Average order', 'Best day', 'Days with sales'],
          data: [
            [
              money(report.revenue),
              '${report.orders}',
              money(report.averageOrder),
              money(report.bestDay),
              '${report.daysWithSales} of ${report.days.length}',
            ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Daily sales', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Orders', 'Revenue'],
          data: [for (final day in report.days) [_ymd(day.date), '${day.orders}', money(day.revenue)]],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Top products', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Product', 'Quantity sold', 'Revenue'],
          data: report.products.isEmpty
              ? [
                  ['No delivered products in this period', '', ''],
                ]
              : [
                  for (final product in report.products) [_plain(product.name), '${product.quantity}', money(product.revenue)],
                ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
        ),
      ],
    ),
  );
  return doc.save();
}

String _plain(String value) => value.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');

String _ymd(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
