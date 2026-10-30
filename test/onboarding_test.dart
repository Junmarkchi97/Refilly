import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/onboarding_screen.dart';
import 'package:refilly/services/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first launch is shown until the user completes or skips it', () async {
    final store = OnboardingStore();
    expect(await store.isComplete(), isFalse);
    await store.markComplete();
    expect(await store.isComplete(), isTrue);
    // Reloading the store reads the persisted completion flag.
    expect(await OnboardingStore().isComplete(), isTrue);
  });

  testWidgets('the welcome tour advances and only finishes when requested', (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async { finishes++; }),
    ));

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(finishes, 0);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('users can skip the tour immediately', (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async { finishes++; }),
    ));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('swiping changes slides and back returns to the previous slide', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async {}),
    ));
    await tester.drag(find.byKey(const Key('onboarding-pages')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('finishing disables further navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        onFinish: () async {},
        finishing: true,
      ),
    ));
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Skip')).onPressed, isNull);
  });
}
