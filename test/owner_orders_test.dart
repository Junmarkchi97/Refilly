import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/owner/owner_orders.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

Order _order({String status = 'preparing', String? riderName = 'John'}) => Order.fromMap({
  'id': 'o1',
  'customer_id': 'c1',
  'station_id': 's1',
  'status': status,
  'delivery_address': 'TEST — accept verification',
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'rider_name': ?riderName,
  if (riderName != null) 'rider_phone': '09752000083',
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
          primaryLabel: 'Mark delivered',
          onPrimary: () {},
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
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('0975 200 0083'), findsWidgets);
    expect(find.text('Deliver to'), findsOneWidget);
    expect(find.text('TEST — accept verification'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('automated test order'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Mark delivered'), findsOneWidget);
    expect(find.text('Change rider'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final name = tester.getTopLeft(find.text('Junmark'));
    final price = tester.getTopLeft(find.text('₱1.00'));
    expect((name.dy - price.dy).abs(), lessThan(2));

    await tester.tap(find.text('Mark delivered'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preparing without a rider shows Assign rider as the primary action', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: OwnerOrderCard(
          order: _order(riderName: null),
          primaryLabel: 'Assign rider',
          onPrimary: () {},
          actions: const [
            Expanded(child: OutlinedButton(onPressed: null, child: Text('Cancel'))),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Assign rider'), findsOneWidget);
    expect(find.text('Mark delivered'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Rider'), findsNothing);
  });

  test('owner can mark delivered only after a rider is assigned', () {
    expect(ownerCanMarkDelivered(_order(status: 'pending', riderName: null)), isFalse);
    expect(ownerCanMarkDelivered(_order(status: 'preparing', riderName: null)), isFalse);
    expect(ownerCanMarkDelivered(_order(status: 'accepted', riderName: null)), isFalse);
    expect(ownerCanMarkDelivered(_order(status: 'preparing')), isTrue);
    expect(ownerCanMarkDelivered(_order(status: 'out_for_delivery')), isTrue);
    expect(ownerCanMarkDelivered(_order(status: 'delivered')), isFalse);
    expect(ownerCanMarkDelivered(_order(status: 'cancelled')), isFalse);
  });

  testWidgets('a rider assignment shows as delivering', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: OwnerOrderCard(
          order: _order(status: 'out_for_delivery'),
          onShare: () {},
          primaryLabel: 'Mark delivered',
          onPrimary: () {},
          actions: const [
            Expanded(child: OutlinedButton(onPressed: null, child: Text('Change rider'))),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(friendlyStatus('out_for_delivery'), 'Delivering');
    expect(find.text('Delivering'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Mark delivered'), findsOneWidget);
    expect(find.text('Change rider'), findsOneWidget);
  });
}
