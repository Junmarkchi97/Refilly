import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';

void main() {
  test('Profile parses saved delivery address fields', () {
    final profile = Profile.fromMap({
      'id': 'user-1',
      'full_name': 'Junmark',
      'phone': '09171234567',
      'role': 'customer',
      'delivery_address': '  12 Aurora Boulevard, Quezon City  ',
      'delivery_lat': 14.635,
      'delivery_lng': 121.046,
    });

    expect(profile.deliveryAddress, '12 Aurora Boulevard, Quezon City');
    expect(profile.deliveryLat, 14.635);
    expect(profile.deliveryLng, 121.046);
    expect(profile.hasSavedAddress, isTrue);
  });

  test('Profile without coordinates is not treated as saved', () {
    final profile = Profile.fromMap({
      'id': 'user-2',
      'full_name': 'Junmark',
      'role': 'customer',
      'delivery_address': 'Quezon City',
    });

    expect(profile.deliveryAddress, 'Quezon City');
    expect(profile.hasSavedAddress, isFalse);
  });

  test('Profile uses account metadata when the address columns are missing', () {
    final profile = Profile.fromMap({
      'id': 'user-3',
      'full_name': 'Junmark',
      'role': 'customer',
    }).applyingMeta({
      'delivery_address': 'Lapu, Polomolok, South Cotabato, 9504',
      'delivery_lat': '6.22',
      'delivery_lng': 125.06,
    });

    expect(profile.deliveryAddress, 'Lapu, Polomolok, South Cotabato, 9504');
    expect(profile.deliveryLat, 6.22);
    expect(profile.deliveryLng, 125.06);
    expect(profile.hasSavedAddress, isTrue);
  });
}
