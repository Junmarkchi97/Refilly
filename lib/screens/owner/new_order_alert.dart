import '../../models/models.dart';
import '../widgets.dart';

/// New orders and customer cancellations after the owner opened the station.
/// The first list only records what is already on screen.
({List<Order> arrived, List<Order> cancelled, bool primed}) noticeOrderChanges({
  required Map<String, String> seen,
  required bool primed,
  required List<Order> orders,
}) {
  if (!primed) {
    for (final order in orders) {
      seen[order.id] = order.status;
    }
    return (arrived: const [], cancelled: const [], primed: true);
  }
  final arrived = <Order>[];
  final cancelled = <Order>[];
  for (final order in orders) {
    final previous = seen[order.id];
    if (previous == null) {
      if (order.status != 'delivered' && order.status != 'cancelled') arrived.add(order);
    } else if (previous != 'cancelled' && order.status == 'cancelled') {
      cancelled.add(order);
    }
    seen[order.id] = order.status;
  }
  return (arrived: arrived, cancelled: cancelled, primed: true);
}

String newOrderMessage(List<Order> orders) {
  final first = orders.first;
  final who = _who(first);
  if (orders.length > 1) {
    final others = orders.length - 1;
    return '$who and $others more placed an order.';
  }
  if (first.total > 0) return '$who placed an order · ${peso(first.total)}.';
  return '$who placed an order.';
}

String cancelledOrderMessage(List<Order> orders) {
  final first = orders.first;
  final who = _who(first);
  if (orders.length > 1) {
    final others = orders.length - 1;
    return '$who and $others more cancelled an order.';
  }
  if (first.total > 0) return '$who cancelled their order · ${peso(first.total)}.';
  return '$who cancelled their order.';
}

String _who(Order order) {
  final name = (order.customer?['full_name'] as String?)?.trim();
  return name == null || name.isEmpty ? 'A customer' : name;
}
