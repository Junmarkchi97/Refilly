import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/models/saved_rider.dart';
import 'package:refilly/screens/owner/owner_orders.dart';
import 'package:refilly/theme.dart';

void main() {
  test('normalizes Philippine rider phones for matching', () {
    expect(normalizeRiderPhone('+63 975 200 0083'), '09752000083');
    expect(normalizeRiderPhone('639752000083'), '09752000083');
    expect(normalizeRiderPhone('9752000083'), '09752000083');
    expect(normalizeRiderPhone('0975-200-0083'), '09752000083');
  });

  test('keeps the newest rider name per phone', () {
    final riders = uniqueRidersByPhone(const [
      SavedRider(name: 'John', phone: '09752000083'),
      SavedRider(name: 'Johnny', phone: '+639752000083'),
      SavedRider(name: 'Ana', phone: '09171234567'),
    ]);
    expect(riders, hasLength(2));
    expect(riders.first.name, 'John');
    expect(riders.first.phone, '09752000083');
    expect(riders.last.name, 'Ana');
  });

  testWidgets('assign dialog uses a saved-riders dropdown to fill the form', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final order = Order.fromMap({
      'id': 'o1',
      'customer_id': 'c1',
      'station_id': 's1',
      'status': 'preparing',
      'delivery_address': 'Cubao',
      'payment_method': 'cod',
      'payment_status': 'unpaid',
      'total': 100,
      'delivery_fee': 0,
      'created_at': '2026-11-03T00:00:00Z',
      'customer': {'full_name': 'Junmark'},
      'order_items': [],
    });

    SavedRider? picked;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await showDialog<SavedRider>(
                context: context,
                builder: (_) => AssignRiderDialog(
                  order: order,
                  loadRiders: () async => const [
                    SavedRider(name: 'John', phone: '09752000083'),
                    SavedRider(name: 'Ana', phone: '09171234567'),
                  ],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<SavedRider>), findsOneWidget);
    expect(find.text('Saved riders'), findsOneWidget);
    expect(find.text('Choose a saved rider'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<SavedRider>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('John · 09752000083').last);
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.first.controller?.text, 'John');
    expect(fields.last.controller?.text, '09752000083');

    await tester.tap(find.text('Save rider'));
    await tester.pumpAndSettle();
    expect(picked?.name, 'John');
    expect(picked?.phone, '09752000083');
  });
}
