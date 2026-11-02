import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/brand.dart';
import 'package:refilly/screens/network_states.dart';
import 'package:refilly/screens/widgets.dart';
import 'package:refilly/theme.dart';

void main() {
  test('identifies missing internet', () {
    expect(classifyLoadFailure(const SocketException('offline')), LoadFailure.offline);
    expect(classifyLoadFailure(Exception('XMLHttpRequest error')), LoadFailure.offline);
  });

  test('distinguishes timed-out from server failures', () {
    expect(classifyLoadFailure(TimeoutException('request timed out')), LoadFailure.timeout);
    expect(classifyLoadFailure(Exception('permission denied')), LoadFailure.server);
  });

  testWidgets('error state offers a working retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: LoadFailureView(
        error: const SocketException('offline'),
        onRetry: () => attempts++,
      ),
    )));
    expect(find.text('No internet connection'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(attempts, 1);
  });

  testWidgets('empty state displays helpful copy and action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: EmptyState(
      icon: Icons.water_drop_outlined,
      title: 'No stations nearby',
      subtitle: 'Try refreshing the list.',
      actionLabel: 'Refresh',
      onAction: () => tapped = true,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('No stations nearby'), findsOneWidget);
    expect(find.text('Try refreshing the list.'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    expect(tapped, isTrue);
  });

  testWidgets('essentials empty state uses the Refilly sticker', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: const Scaffold(
        backgroundColor: RF.bg,
        body: EmptyState(
          artwork: RefillySticker(),
          title: 'No usuals yet',
          subtitle: 'After a delivery, save the order to your essentials. Next time it takes one tap to refill.',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(RefillySticker), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(find.text('No usuals yet'), findsOneWidget);
  });

  testWidgets('slow connection hint appears after delay', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SlowLoadingHint(delay: Duration(seconds: 2)),
    )));
    expect(find.text('Loading…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('This is taking longer than usual…'), findsOneWidget);
  });

  test('hides database errors behind a plain failure', () {
    final copy = describeFailure(
      Exception(
        "PostgrestException(message: Could not find the 'delivery_address' column of 'profiles' in the schema cache, code: PGRST204, details: , hint: null)",
      ),
      failed: 'Could not save your address.',
    );
    expect(copy.kind, AppNotice.failed);
    expect(copy.message, 'Could not save your address.');
    expect(copy.message, isNot(contains('PGRST')));
    expect(copy.message, isNot(contains('delivery_address')));
  });

  test('keeps a short sign-in message and names offline separately', () {
    final auth = describeFailure(
      Exception('AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)'),
      failed: 'Could not sign in.',
    );
    expect(auth.message, 'Invalid login credentials');

    final offline = describeFailure(const SocketException('Failed host lookup'));
    expect(offline.kind, AppNotice.offline);
    expect(offline.message, contains('No internet connection'));

    final timeout = describeFailure(TimeoutException('request timed out'));
    expect(timeout.kind, AppNotice.timeout);

    final readable = describeFailure(StateError('This saved order is unavailable.'));
    expect(readable.message, 'This saved order is unavailable.');
  });

  testWidgets('success notice shows the saved-address confirmation', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppNotice(context, 'Address updated', kind: AppNotice.success),
            child: const Text('Save'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Address updated'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}
