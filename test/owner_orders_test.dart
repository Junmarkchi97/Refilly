import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/owner/owner_orders.dart';
import 'package:refilly/theme.dart';

Order _order() => Order.fromMap({
  'id': 'o1',
  'customer_id': 'c1',
  'station_id': 's1',
  'status': 'preparing',
  'delivery_address': 'TEST — accept verification',
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'rider_name': 'John',
  'rider_phone': '09752000083',
  'contact_phone': '09752000083',
  'notes': 'automated test order',
  'total': 1,
  'delivery_fee': 0,
  'created_at': '2026-11-02T16:45:00Z',
  'customer': {'full_name': 'Junmark'},
  'order_items': [],
});

void main() {
  testWidgets('owner order card labels delivery details and keeps the header aligned', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: OwnerOrderCard(
          order: _order(),
          onShare: () {},
          actions: const [
            Expanded(child: OutlinedButton(onPressed: null, child: Text('Change rider'))),
            SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: null, child: Text('Cancel'))),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Junmark'), findsOneWidget);
    expect(find.text('₱1.00'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.textContaining('Cash'), findsOneWidget);
    expect(find.text('0 items'), findsNothing);
    expect(find.text('COD'), findsNothing);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('0975 200 0083'), findsWidgets);
    expect(find.text('Deliver to'), findsOneWidget);
    expect(find.text('TEST — accept verification'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('automated test order'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);

    final name = tester.getTopLeft(find.text('Junmark'));
    final price = tester.getTopLeft(find.text('₱1.00'));
    expect((name.dy - price.dy).abs(), lessThan(2));
  });
}
