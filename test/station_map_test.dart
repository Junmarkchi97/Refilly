import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/owner/station_form.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('station map is large and has rounded corners', (tester) async {
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

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(body: StationForm(ownerId: 'owner', station: station, onSaved: () {})),
    ));
    await tester.pump();

    final map = find.byType(FlutterMap);
    expect(map, findsOneWidget);
    expect(tester.getSize(map).height, greaterThan(260));
    final clip = tester.widget<ClipRRect>(find.ancestor(of: map, matching: find.byType(ClipRRect)));
    expect(clip.borderRadius, BorderRadius.circular(24));

    expect(tester.widget<FlutterMap>(map).options.onTap, isNull);
    expect(find.text('Pin is locked. Tap Edit on the map to move it.'), findsOneWidget);

    final list = find.ancestor(of: find.text('Edit'), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Edit'), 300, scrollable: list);
    await tester.pump();
    await tester.tap(find.text('Edit'));
    await tester.pump();

    expect(tester.widget<FlutterMap>(map).options.onTap, isNotNull);
    expect(find.text('Tap the map to move your station pin'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(tester.widget<FlutterMap>(map).options.onTap, isNull);
    expect(find.text('Edit'), findsOneWidget);
  });
}
