import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/design.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('handoff select cards keep icon and label centered', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SelectCard(
                  selected: true,
                  onTap: () {},
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apartment_rounded, size: 20),
                      SizedBox(height: 3),
                      Text('Lobby', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectCard(
                  selected: false,
                  onTap: () {},
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.door_front_door_outlined, size: 20),
                      SizedBox(height: 3),
                      Text('Doorstep', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final lobbyCard = tester.getRect(find.widgetWithText(SelectCard, 'Lobby'));
    final lobbyIcon = tester.getCenter(find.byIcon(Icons.apartment_rounded));
    final lobbyText = tester.getCenter(find.text('Lobby'));
    expect((lobbyIcon.dx - lobbyCard.center.dx).abs(), lessThan(2));
    expect((lobbyText.dx - lobbyCard.center.dx).abs(), lessThan(2));
    expect(lobbyText.dy - lobbyCard.top, greaterThan(20));
    expect(lobbyCard.bottom - lobbyText.dy, greaterThan(16));

    final doorCard = tester.getRect(find.widgetWithText(SelectCard, 'Doorstep'));
    final doorIcon = tester.getCenter(find.byIcon(Icons.door_front_door_outlined));
    final doorText = tester.getCenter(find.text('Doorstep'));
    expect((doorIcon.dx - doorCard.center.dx).abs(), lessThan(2));
    expect((doorText.dx - doorCard.center.dx).abs(), lessThan(2));
  });
}
