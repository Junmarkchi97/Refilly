import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/customer/reorder.dart';

Product product(String id, double price, {bool available = true}) => Product.fromMap({
  'id': id, 'station_id': 'station-1', 'name': 'Water', 'unit': 'gallon',
  'price': price, 'is_available': available,
});

Order orderWithItems(List<Map<String, dynamic>> items, {String status = 'delivered'}) => Order.fromMap({
  'id': 'order-1',
  'station_id': 'station-1',
  'customer_id': 'customer-1',
  'status': status,
  'delivery_address': 'Quezon City',
  'payment_method': 'cod',
  'payment_status': 'paid',
  'total': 100,
  'created_at': '2026-10-31T00:00:00Z',
  'order_items': items,
});

Map<String, dynamic> item(String? id, String name, int quantity, double unitPrice) => {
  'product_id': id, 'product_name': name,
  'quantity': quantity, 'unit_price': unitPrice,
};

void main() {
  test('reorder restores the original product quantities at current prices', () {
    final order = orderWithItems([item('water-a', 'Water A', 3, 20)]);
    final result = ReorderCart.build(order, [product('water-a', 20)]);
    expect(result.quantities, {'water-a': 3});
    expect(result.unavailable, isEmpty);
    expect(result.priceChanges, isEmpty);
  });

  test('reorder warns about changed prices without using historical pricing', () {
    final order = orderWithItems([item('water-a', 'Water A', 2, 20)]);
    final result = ReorderCart.build(order, [product('water-a', 25)]);
    expect(result.quantities, {'water-a': 2});
    expect(result.priceChanges, ['Water A']);
  });

  test('removed, unlinked or unavailable products cannot enter new cart', () {
    final order = orderWithItems([
      item('water-a', 'No longer sold', 2, 20),
      item(null, 'Deleted product', 1, 10),
      item('water-b', 'Water B', 4, 30),
    ]);
    final result = ReorderCart.build(order, [product('water-a', 20, available: false), product('water-b', 30)]);
    expect(result.quantities, {'water-b': 4});
    expect(result.unavailable, ['No longer sold', 'Deleted product']);
  });

  test('reorder merges duplicate historic line items', () {
    final order = orderWithItems([item('water-a', 'Water A', 1, 20), item('water-a', 'Water A', 3, 20)]);
    expect(ReorderCart.build(order, [product('water-a', 20)]).quantities, {'water-a': 4});
  });
}
