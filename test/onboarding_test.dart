import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/onboarding_screen.dart';
import 'package:refilly/services/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The welcome photo wall drifts continuously, so settle page transitions by time.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapAndSettle(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester);
}

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

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tapAndSettle(tester, 'Get started');
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tapAndSettle(tester, 'Continue');
    await tapAndSettle(tester, 'Continue');
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(finishes, 0);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('users can skip the tour from any step', (tester) async {
    var finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async { finishes++; }),
    ));
    await tapAndSettle(tester, 'Get started');
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(finishes, 1);
  });

  testWidgets('existing customers can go straight to log in', (tester) async {
    var signIns = 0, finishes = 0;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async { finishes++; }, onSignIn: () async { signIns++; }),
    ));
    await tester.tap(find.text('I already have an account'));
    await tester.pump();
    expect(signIns, 1);
    expect(finishes, 0);
  });

  testWidgets('swiping changes pages and back returns to the previous one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async {}),
    ));
    await tester.drag(find.byKey(const Key('onboarding-pages')), const Offset(-400, 0));
    await settle(tester);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('finishing disables further navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onFinish: () async {}, finishing: true),
    ));
    final button = tester.widget<FilledButton>(find.byKey(const Key('onboarding-primary')));
    expect(button.onPressed, isNull);
  });

  testWidgets('reduced motion keeps the tour readable and navigation immediate', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: OnboardingScreen(onFinish: () async {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('the tour fits a small screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: OnboardingScreen(onFinish: () async {}, onSignIn: () async {}),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tapAndSettle(tester, 'Get started');
    expect(tester.takeException(), isNull);
    for (var page = 0; page < 2; page++) {
      await tapAndSettle(tester, 'Continue');
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Create account'), findsOneWidget);
  });
}
