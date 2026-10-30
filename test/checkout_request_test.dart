import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/services/checkout_request.dart';

void main() {
  test('a checkout retry reuses one stable request ID', () {
    final request = CheckoutRequest();
    final previous = request.id;
    expect(request.id, previous);
    expect(previous, matches(RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    )));
  });

  test('editing checkout details creates a new request ID', () {
    final request = CheckoutRequest();
    final original = request.id;
    request.reset();
    expect(request.id, isNot(original));
  });

  test('different checkout attempts have distinct IDs', () {
    final ids = List.generate(200, (_) => CheckoutRequest.newId()).toSet();
    expect(ids.length, 200);
  });
}
