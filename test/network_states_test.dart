import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/network_states.dart';
import 'package:refilly/screens/widgets.dart';

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

  testWidgets('slow connection hint appears after delay', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SlowLoadingHint(delay: Duration(seconds: 2)),
    )));
    expect(find.text('Loading…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('This is taking longer than usual…'), findsOneWidget);
  });
}
