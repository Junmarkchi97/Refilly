import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('station orb shows the store photo at hero size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: const Scaffold(
        body: Center(
          child: StationOrb(
            photoUrl: 'https://example.com/station.jpg',
            label: 'Crystal Clear Station - Makati',
            size: 124,
          ),
        ),
      ),
    ));
    await tester.pump();

    final avatar = tester.widget<StationAvatar>(find.byType(StationAvatar));
    expect(avatar.url, 'https://example.com/station.jpg');
    expect(avatar.size, 124);
    expect(find.byType(ProductOrb), findsNothing);
    expect(find.bySemanticsLabel('Crystal Clear Station - Makati'), findsOneWidget);

    while (tester.takeException() != null) {}
  });
}
