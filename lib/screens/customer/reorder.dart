import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import 'station_screen.dart';
import '../../models/refill_routine.dart';

class ReorderCart {
  const ReorderCart(this.quantities, this.unavailable, this.priceChanges);
  final Map<String, int> quantities;
  final List<String> unavailable;
  final List<String> priceChanges;

  bool get hasItems => quantities.isNotEmpty;

  static ReorderCart build(Order order, List<Product> currentProducts) {
    final products = {for (final p in currentProducts) p.id: p};
    final quantities = <String, int>{};
    final unavailable = <String>[];
    final priceChanges = <String>[];
    for (final item in order.items) {
      final product = item.productId == null ? null : products[item.productId];
      if (product == null || !product.isAvailable) {
        unavailable.add(item.productName);
        continue;
      }
      quantities[product.id] = (quantities[product.id] ?? 0) + item.quantity;
      if ((product.price - item.unitPrice).abs() > 0.001) {
        priceChanges.add(item.productName);
      }
    }
    return ReorderCart(quantities, unavailable, priceChanges);
  }
}

/// Opens a reviewable, prefilled cart; never submits an order automatically.
Future<void> startReorder(BuildContext context, Order order, Profile profile, {RefillRoutine? routine}) async {
  if (order.status != 'delivered' && order.status != 'cancelled') return;
  if (routine != null) {
    final active = await Api.hasMatchingActiveOrder(order);
    if (!context.mounted) return;
    if (active) {
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Refill already in progress'),
        content: const Text('You already have an active order for these essentials. Check Orders before ordering again.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ));
      return;
    }
  }
  // Give feedback on slow connections and prevent repeated taps while loading.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 16),
        Expanded(child: Text('Checking current products and prices…')),
      ]),
    ),
  );
  Station? station;
  ReorderCart? cart;
  Object? error;
  try {
    final stations = await Api.stations().timeout(const Duration(seconds: 20));
    for (final candidate in stations) {
      if (candidate.id == order.stationId) {
        station = candidate;
        break;
      }
    }
    if (station == null) throw StateError('This water station is no longer available.');
    if (!station.isOpen) throw StateError('This station is currently closed. Please try later.');
    final products = await Api.products(order.stationId, onlyAvailable: false)
        .timeout(const Duration(seconds: 20));
    cart = ReorderCart.build(order, products);
    if (!cart.hasItems) throw StateError('The items from this order are no longer available.');
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (error != null) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unable to reorder'),
        content: Text(error.toString().replaceFirst('Bad state: ', '')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
    return;
  }
  final readyCart = cart!;
  final notice = <String>[
    if (readyCart.unavailable.isNotEmpty)
      'Unavailable items will be skipped: ${readyCart.unavailable.join(', ')}.',
    if (readyCart.priceChanges.isNotEmpty)
      'Prices have changed for: ${readyCart.priceChanges.join(', ')}.',
    'You can edit quantities and confirm the latest total before ordering.',
  ];
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Reorder from this station?'),
      content: Text(notice.join('\n\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Review cart')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => StationScreen(
      station: station!,
      profile: profile,
      initialQuantities: readyCart.quantities,
      refillRoutineId: routine?.id,
    ),
  ));
}
