import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/owner/new_order_alert.dart';

Order _order(String id, {String status = 'pending', String name = 'Junmark', num total = 125}) => Order.fromMap({
  'id': id,
  'customer_id': 'c1',
  'station_id': 's1',
  'status': status,
  'delivery_address': '12 Kalayaan Ave',
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'total': total,
  'delivery_fee': 0,
  'created_at': '2026-11-03T02:00:00Z',
  'customer': {'full_name': name},
  'order_items': [],
});

void main() {
  test('a new order alerts the owner after the station list is already open', () {
    final seen = <String, String>{};
    final existing = _order('old');

    final first = noticeOrderChanges(seen: seen, primed: false, orders: [existing]);
    expect(first.primed, isTrue);
    expect(first.arrived, isEmpty);
    expect(first.cancelled, isEmpty);

    final again = noticeOrderChanges(seen: seen, primed: first.primed, orders: [existing]);
    expect(again.arrived, isEmpty);
    expect(again.cancelled, isEmpty);

    final fresh = _order('new', name: 'Ana');
    final next = noticeOrderChanges(seen: seen, primed: again.primed, orders: [existing, fresh]);
    expect(next.arrived.map((order) => order.id), ['new']);
    expect(next.cancelled, isEmpty);
    expect(newOrderMessage(next.arrived), 'Ana placed an order · ₱125.00.');
  });

  test('a customer cancellation alerts the owner', () {
    final seen = <String, String>{};
    final open = _order('old', name: 'Ana');
    final primed = noticeOrderChanges(seen: seen, primed: false, orders: [open]).primed;

    final next = noticeOrderChanges(
      seen: seen,
      primed: primed,
      orders: [_order('old', name: 'Ana', status: 'cancelled')],
    );
    expect(next.arrived, isEmpty);
    expect(next.cancelled.map((order) => order.id), ['old']);
    expect(cancelledOrderMessage(next.cancelled), 'Ana cancelled their order · ₱125.00.');

    final again = noticeOrderChanges(
      seen: seen,
      primed: next.primed,
      orders: [_order('old', name: 'Ana', status: 'cancelled')],
    );
    expect(again.cancelled, isEmpty);
  });

  test('delivered history that appears later does not alert', () {
    final seen = <String, String>{};
    final primed = noticeOrderChanges(seen: seen, primed: false, orders: [_order('old')]).primed;
    final next = noticeOrderChanges(
      seen: seen,
      primed: primed,
      orders: [_order('old'), _order('done', status: 'delivered')],
    );
    expect(next.arrived, isEmpty);
    expect(next.cancelled, isEmpty);
  });
}