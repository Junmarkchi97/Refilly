import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/brand.dart';
import 'package:refilly/screens/customer/checkout_screen.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('confirm delivery uses the top space and keeps a close button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final station = Station.fromMap({
      'id': 's1',
      'name': 'AquaPure Refilling - Cubao',
      'lat': 14.65,
      'lng': 121.05,
      'is_open': true,
      'delivery_radius_km': 10,
      'delivery_fee': 50,
    });
    final product = Product.fromMap({
      'id': 'p1',
      'station_id': 's1',
      'name': 'Purified Water Refill',
      'unit': '5 gal',
      'price': 30,
    });
    final profile = Profile.fromMap({'id': 'u1', 'full_name': 'Junmark', 'role': 'customer'});

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: CheckoutScreen(station: station, cart: {product: 1}, profile: profile),
    ));
    await tester.pump();

    expect(find.byType(RefillyMark), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Confirm delivery'), findsOneWidget);

    final title = tester.getTopLeft(find.text('Confirm delivery'));
    expect(title.dy, lessThan(80));
    final close = tester.getCenter(find.byIcon(Icons.close_rounded));
    expect((close.dy - tester.getCenter(find.text('Confirm delivery')).dy).abs(), lessThan(24));
  });
}
