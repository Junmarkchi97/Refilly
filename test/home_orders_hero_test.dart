import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/customer/home_tab.dart';

Order _order(String status) => Order.fromMap({
  'id': 'o-$status',
  'customer_id': 'u1',
  'station_id': 's1',
  'status': status,
  'delivery_address': 'Cubao',
  'payment_method': 'cod',
  'payment_status': 'unpaid',
  'subtotal': 30,
  'delivery_fee': 0,
  'total': 30,
  'created_at': '2026-11-03T00:00:00Z',
  'updated_at': '2026-11-03T00:00:00Z',
  'order_items': const [],
});

void main() {
  test('home waits for orders before showing Order now', () {
    expect(
      homeOrdersHero(const AsyncSnapshot.waiting()),
      HomeOrdersHero.loading,
    );
  });

  test('home does not leave a stuck loading bar after an orders error', () {
    expect(
      homeOrdersHero(const AsyncSnapshot.withError(ConnectionState.active, 'offline')),
      HomeOrdersHero.empty,
    );
    expect(
      homeOrdersHero(const AsyncSnapshot.nothing()),
      HomeOrdersHero.empty,
    );
  });

  test('home shows Order now only after an empty orders list loads', () {
    expect(
      homeOrdersHero(const AsyncSnapshot.withData(ConnectionState.active, <Order>[])),
      HomeOrdersHero.empty,
    );
    expect(
      homeOrdersHero(AsyncSnapshot.withData(ConnectionState.active, [_order('delivered')])),
      HomeOrdersHero.empty,
    );
  });

  test('home shows the active delivery once orders arrive', () {
    expect(
      homeOrdersHero(AsyncSnapshot.withData(ConnectionState.active, [_order('pending')])),
      HomeOrdersHero.upcoming,
    );
  });
}
