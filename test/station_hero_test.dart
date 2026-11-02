import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('station hero is full width with the store photo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: const Scaffold(
        body: StationHero(
          photoUrl: 'https://example.com/station.jpg',
          label: 'BlueDrop - Manila',
          height: 220,
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(StationHero), findsOneWidget);
    expect(find.byType(StationAvatar), findsNothing);
    expect(find.bySemanticsLabel('BlueDrop - Manila'), findsOneWidget);

    final size = tester.getSize(find.byType(StationHero));
    expect(size.width, 390);
    expect(size.height, 220);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    final provider = image.image;
    final network = provider is ResizeImage ? provider.imageProvider : provider;
    expect(network, isA<NetworkImage>());
    expect((network as NetworkImage).url, 'https://example.com/station.jpg');

    while (tester.takeException() != null) {}
  });

  testWidgets('station hero falls back when the store has no photo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: const Scaffold(
        body: StationHero(label: 'AquaPure', height: 180),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
