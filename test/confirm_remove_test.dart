import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('confirmRemove cancels without deleting', (tester) async {
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              removed = await confirmRemove(
                context,
                title: 'Remove profile photo?',
                message: 'Your account will show your initial until you add a new photo.',
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Remove profile photo?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removed, isFalse);
  });

  testWidgets('confirmRemove returns true when Remove is tapped', (tester) async {
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              removed = await confirmRemove(
                context,
                title: 'Remove station photo?',
                message: 'Customers will see the default mark until you upload a new photo.',
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
}
