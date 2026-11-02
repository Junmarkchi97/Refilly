import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('logout button asks for confirmation and cancel stays put', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(body: Center(child: logoutButton())),
    ));

    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('You will need to sign in again to place an order.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('confirming the logout modal reports yes without leaving the dialog up', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const LogoutConfirmDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Log out?'), findsNothing);
  });

  testWidgets('dismissing the logout modal does not confirm', (tester) async {
    bool? result = true;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const LogoutConfirmDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
