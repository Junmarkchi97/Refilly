import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/customer/owner_paywall_screen.dart';
import 'package:refilly/theme.dart';

void main() {
  test('yearly is 40% off monthly', () {
    expect(OwnerPricing.monthly, 249);
    expect(OwnerPricing.yearly, 1793);
    expect(OwnerPricing.yearlyPerMonth, 149);
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
    expect(find.text('Continue with Yearly · ₱1,793'), findsOneWidget);
    expect(find.text('SAVE 40%'), findsOneWidget);
    // Both plans must be on-screen without scrolling on a typical phone.
    expect(find.text('Monthly'), findsOneWidget);
    expect(tester.getRect(find.text('Monthly')).bottom, lessThan(844 - 120));

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.text('Continue with Monthly · ₱249'), findsOneWidget);

    await tester.tap(find.text('Have a voucher code?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pump();
    await tester.tap(find.text('Apply voucher'));
    await tester.pumpAndSettle();
    expect(redeemed, 'nope');
    expect(find.text('That voucher code is not valid.'), findsOneWidget);
  });
}
