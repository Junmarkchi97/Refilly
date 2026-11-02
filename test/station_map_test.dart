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
  });
}
