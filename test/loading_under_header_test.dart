import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/screens/motion.dart';
import 'package:refilly/theme.dart';

void main() {
  testWidgets('orders loading skeletons sit below the app bar with a gap', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: refillyTheme(),
        home: Scaffold(
          backgroundColor: RF.bg,
          appBar: AppBar(
            backgroundColor: RF.bg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 72,
            title: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(
                  'AquaPure Refilling - Cubao',
                  style: TextStyle(fontSize: 13, color: RF.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          body: const StateSwitcher(child: SkeletonList()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Loading…'), findsNothing);

    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    final firstSkeleton = tester.getRect(find.byType(Container).first);
    // SkeletonList pads 16px under the AppBar so the top is not cut off.
    expect(firstSkeleton.top, greaterThanOrEqualTo(appBarBottom + 15));
  });
}
