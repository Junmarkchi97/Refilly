import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/owner/cash_confetti.dart';

Future<void> _drainConfetti(WidgetTester tester) async {
  for (var i = 0; i < 180; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('mark delivered plays a party confetti burst', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => celebrateOrderDelivered(context),
            child: const Text('Mark delivered'),
          ),
        ),
      ),
    ));

    expect(find.byType(Confetti), findsNothing);
    await tester.tap(find.text('Mark delivered'));
    await tester.pump();

    expect(find.byType(Confetti), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _drainConfetti(tester);
    expect(find.byType(Confetti), findsNothing);
  });

  testWidgets('cash collected plays a money / coin burst', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => celebrateCashCollected(context),
            child: const Text('Cash collected'),
          ),
        ),
      ),
    ));

    expect(find.byType(Confetti), findsNothing);
    await tester.tap(find.text('Cash collected'));
    await tester.pump();

    expect(find.byType(Confetti), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _drainConfetti(tester);
    expect(find.byType(Confetti), findsNothing);
  });
}
