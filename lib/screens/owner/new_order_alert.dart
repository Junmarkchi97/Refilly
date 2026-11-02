import '../../models/models.dart';
import '../widgets.dart';

/// Orders that showed up after the owner opened the station.
/// The first list only fills [seen], so orders already on screen do not alert.
({List<Order> arrived, bool primed}) noticeNewOrders({
  required Set<String> seen,
  required bool primed,
  required List<Order> orders,
}) {
  if (!primed) {
    for (final order in orders) {
      seen.add(order.id);
    }
    return (arrived: const [], primed: true);
  }
  final arrived = <Order>[
    for (final order in orders)
      if (seen.add(order.id) && order.status != 'delivered' && order.status != 'cancelled') order,
  ];
  return (arrived: arrived, primed: true);
}

String newOrderMessage(List<Order> orders) {
  final first = orders.first;
  final name = (first.customer?['full_name'] as String?)?.trim();
  final who = name == null || name.isEmpty ? 'A customer' : name;
  if (orders.length > 1) {
    final others = orders.length - 1;
    return '$who and $others more placed an order.';
  }
  if (first.total > 0) return '$who placed an order · ${peso(first.total)}.';
  return '$who placed an order.';
}
