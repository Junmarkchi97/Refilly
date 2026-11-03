import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/customer/owner_paywall_screen.dart';
import 'package:refilly/services/owner_billing_ids.dart';
import 'package:refilly/theme.dart';

void main() {
  test('yearly is 40% off monthly and includes a 7-day trial', () {
    expect(OwnerPricing.monthly, 249);
    expect(OwnerPricing.yearly, 1793);
    expect(OwnerPricing.yearlyPerMonth, 149);
    expect(OwnerPricing.trialDays, 7);
    expect(OwnerPricing.trialLabel, '7-day free trial');
  });

  testWidgets('paywall defaults to yearly, switches plans, and redeems a voucher', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    String? redeemed;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: OwnerPaywallScreen(
        redeemVoucher: (c) async {
          redeemed = c;
          if (c != 'REFILLY6') throw Exception('That voucher code is not valid.');
          return 6;
        },
        choosePlan: (_) async {},
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('7-day free trial'), findsWidgets);
    expect(find.textContaining('billed automatically'), findsOneWidget);
    expect(find.text('Start free trial · Yearly ₱1,793'), findsOneWidget);
    expect(find.text('SAVE 40%'), findsOneWidget);
    // Both plans must be on-screen without scrolling on a typical phone.
    expect(find.text('Monthly'), findsOneWidget);
    expect(tester.getRect(find.text('Monthly')).bottom, lessThan(844 - 120));

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.text('Start free trial · Monthly ₱249'), findsOneWidget);

    await tester.tap(find.text('Have a voucher code?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pump();
    await tester.tap(find.text('Apply voucher'));
    await tester.pumpAndSettle();
    expect(redeemed, 'nope');
    expect(find.text('That voucher code is not valid.'), findsOneWidget);
  });

  testWidgets('the free trial opens the store payment before the plan is saved', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final steps = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: OwnerPaywallScreen(
        purchase: (plan) async => steps.add('purchase-${plan.name}'),
        choosePlan: (plan) async {
          steps.add('save-$plan');
          throw Exception('stop after save');
        },
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Start free trial · Yearly ₱1,793'));
    await tester.pump();
    expect(steps, ['purchase-yearly', 'save-yearly']);
    expect(find.text('Start free trial · Yearly ₱1,793'), findsOneWidget);
  });

  testWidgets('closing the store sheet does not save a plan', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    var saved = false;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: OwnerPaywallScreen(
        purchase: (_) async => throw const StorePurchaseCancelled(),
        choosePlan: (_) async => saved = true,
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Start free trial · Yearly ₱1,793'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('Start free trial · Yearly ₱1,793'), findsOneWidget);
  });
}
