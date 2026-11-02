import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/owner/owner_products.dart';
import 'package:refilly/theme.dart';

Product _product({bool available = true}) => Product.fromMap({
  'id': 'p1',
  'station_id': 's1',
  'name': 'Purified Water Refill (5 gal)',
  'unit': 'gallon',
  'price': 30,
  'is_available': available,
});

void main() {
  testWidgets('each product can be edited, removed, or hidden', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    bool? available;
    var edited = false;
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: OwnerProductCard(
          product: _product(),
          onEdit: () => edited = true,
          onRemove: () => removed = true,
          onAvailable: (v) => available = v,
        ),
      ),
    ));

    expect(find.text('Purified Water Refill (5 gal)'), findsOneWidget);
    expect(find.text('₱30.00 / gallon'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('Remove'));
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(edited, isTrue);
    expect(removed, isTrue);
    expect(available, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remove asks for confirmation', (tester) async {
    bool? result = true;
    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => const RemoveProductDialog(name: 'Alkaline Water Refill (5 gal)'),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Remove product?'), findsOneWidget);
    expect(find.textContaining('Alkaline Water Refill'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('product form gives the photo note the full dialog width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final name = TextEditingController(text: 'Alkaline Water Refill (5 gal)');
    final unit = TextEditingController(text: 'gallon');
    final price = TextEditingController(text: '45.00');
    addTearDown(() {
      name.dispose();
      unit.dispose();
      price.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      theme: refillyTheme(),
      home: Scaffold(
        body: ProductFormDialog(
          isNew: false,
          imageBytes: null,
          imageUrl: 'https://example.com/jug.jpg',
          categories: [Category.fromMap({'id': 'c1', 'slug': 'water', 'name': 'Water'})],
          categoryId: 'c1',
          onCategory: (_) {},
          name: name,
          unit: unit,
          price: price,
          onPickPhoto: () {},
          onRemovePhoto: () {},
          onCancel: () {},
          onSave: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit product'), findsOneWidget);
    expect(find.text('Replace photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsOneWidget);
    expect(tester.getSize(find.text('JPG, PNG, or WebP. Up to 5 MB.')).width, greaterThan(240));
    final cancel = tester.getSize(find.widgetWithText(OutlinedButton, 'Cancel'));
    final save = tester.getSize(find.widgetWithText(FilledButton, 'Save'));
    expect((cancel.width - save.width).abs(), lessThan(2));
    expect((cancel.height - save.height).abs(), lessThan(2));
  });
}
