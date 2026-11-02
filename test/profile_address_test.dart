import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refilly/models/models.dart';
import 'package:refilly/screens/customer/profile_photo.dart';

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
    expect(profile.avatarUrl, isNull);
  });

  test('Profile keeps a photo while filling a missing address', () {
    final profile = Profile.fromMap({
      'id': 'user-4',
      'full_name': 'Junmark',
      'role': 'customer',
      'avatar_url': ' https://example.com/avatar.jpg ',
    }).applyingMeta({
      'delivery_address': 'Lapu-Lapu, Central Visayas',
      'delivery_lat': 10.31,
      'delivery_lng': 123.95,
    });

    expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
    expect(profile.deliveryAddress, 'Lapu-Lapu, Central Visayas');
  });

  test('profile photo path must stay inside the signed-in user folder', () {
    expect(ownedAvatarPath('user-1', {'avatar_path': 'user-1/profile-avatar.jpg'}), 'user-1/profile-avatar.jpg');
    expect(ownedAvatarPath('user-1', {'avatar_path': 'user-2/profile-avatar.jpg'}), isNull);
    expect(ownedAvatarPath('user-1', {'avatar_path': 'user-1/../secret.jpg'}), isNull);
    expect(ownedAvatarPath('user-1', {'avatar_path': 'user-1/nested/photo.jpg'}), isNull);
    expect(ownedAvatarPath('user-1', {'avatar_path': null}), isNull);
  });

  testWidgets('account photo shows the initial and a change button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableProfilePhoto(
          profile: Profile.fromMap({'id': 'user-1', 'full_name': 'Junmark', 'role': 'customer'}),
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('J'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
  });
}
