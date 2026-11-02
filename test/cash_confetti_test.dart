import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/owner/cash_confetti.dart';

void main() {
  testWidgets('confirming cash plays a confetti burst', (tester) async {
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

    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(Confetti), findsNothing);
  });
}
