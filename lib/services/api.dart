import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:typed_data';

import '../config.dart';
import '../models/models.dart';
import '../models/refill_routine.dart';
import '../models/saved_rider.dart';

SupabaseClient get sb => Supabase.instance.client;

const orderSelect =
    '*, order_items(*, product:products(image_url)), customer:profiles!orders_customer_id_fkey(full_name, phone), station:stations(name, lat, lng, photo_url, phone)';

class Api {
  static Future<List<RefillRoutine>> refillRoutines() async {
    final user = sb.auth.currentUser;
    if (user == null) return const [];
    final rows = await sb.from('refill_routines').select()
        .eq('customer_id', user.id).order('next_due_on');
    return rows.map(RefillRoutine.fromMap).toList();
  }

  /// A safety check before opening a routine's cart. This does not submit an order.
  /// The cart still goes through checkout and its normal submit guard.
  static Future<bool> hasMatchingActiveOrder(Order source) async {
    final customer = sb.auth.currentUser;
    if (customer == null) return false;
    final rows = await sb.from('orders').select(orderSelect)
        .eq('customer_id', customer.id).eq('station_id', source.stationId)
        .inFilter('status', ['pending', 'accepted', 'preparing', 'out_for_delivery'])
        .limit(30);
    final expected = <String, int>{};
    for (final item in source.items) {
      if (item.productId != null) {
        expected[item.productId!] = (expected[item.productId!] ?? 0) + item.quantity;
      }
    }
    if (expected.isEmpty) return false;
    for (final row in rows) {
      final order = Order.fromMap(row);
      final actual = <String, int>{};
      for (final item in order.items) {
        if (item.productId != null) {
          actual[item.productId!] = (actual[item.productId!] ?? 0) + item.quantity;
        }
      }
      if (actual.length == expected.length &&
          expected.keys.every((key) => actual[key] == expected[key])) {
        return true;
      }
    }
    return false;
  }

  static Future<String> saveRefillRoutine(String orderId, int days) async =>
      await sb.rpc('save_refill_routine', params: {
        'p_order': orderId, 'p_interval_days': days,
      }) as String;

  static Future<void> manageRefillRoutine(String id, String action, {int? days}) async {
    await sb.rpc('manage_refill_routine', params: {
      'p_routine': id, 'p_action': action, 'p_interval_days': days,
    });
  }

  static Future<void> recordRefillOrder(String routineId, String orderId) async {
    await sb.rpc('record_refill_routine_order', params: {
      'p_routine': routineId, 'p_order': orderId,
    });
  }

  static Future<bool> hasUnreadNotifications() async =>
      (await sb.from('user_notifications').select('id').eq('is_read', false).limit(1)).isNotEmpty;

  static Future<int> claimRefillReminders() async =>
      (await sb.rpc('claim_refill_reminders') as num).toInt();

  static Future<Profile?> me() async {
    final u = sb.auth.currentUser;
    if (u == null) return null;
    final r = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
    if (r == null) return null;
    return _withAvatar(Profile.fromMap(r).applyingMeta(_metaMap(u.userMetadata)), u.id, u.userMetadata);
  }

  /// Profile photos are stored in the existing private `owner-docs` bucket,
  /// which already lets each signed-in user write their own folder. The live
  /// profiles table has no avatar column, so the path is kept on the account.
  static Future<Profile> saveProfilePhoto(Uint8List bytes, String ext, String contentType) async {
    final u = sb.auth.currentUser;
    if (u == null) throw StateError('Sign in to update your photo');
    final safeExt = ext == 'jpeg' ? 'jpg' : ext;
    if (!const {'jpg', 'png', 'webp'}.contains(safeExt)) {
      throw ArgumentError('Use a JPG, PNG, or WebP photo');
    }
    final path = '${u.id}/profile-avatar.$safeExt';
    await sb.storage.from('owner-docs').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    final data = Map<String, dynamic>.from(u.userMetadata ?? {});
    data['avatar_path'] = path;
    await sb.auth.updateUser(UserAttributes(data: data));
    final row = await sb.from('profiles').select().eq('id', u.id).single();
    return _withAvatar(Profile.fromMap(row).applyingMeta(data), u.id, data);
  }

  static Future<Profile> removeProfilePhoto() async {
    final u = sb.auth.currentUser;
    if (u == null) throw StateError('Sign in to update your photo');
    final data = Map<String, dynamic>.from(u.userMetadata ?? {});
    data['avatar_path'] = null;
    await sb.auth.updateUser(UserAttributes(data: data));
    final row = await sb.from('profiles').select().eq('id', u.id).single();
    return Profile.fromMap(row).applyingMeta(data);
  }

  static Future<Profile> _withAvatar(Profile profile, String userId, Object? meta) async {
    final path = ownedAvatarPath(userId, meta);
    if (path == null) return profile;
    try {
      final url = await sb.storage.from('owner-docs').createSignedUrl(path, 60 * 60 * 24 * 7);
      return profile.withAvatarUrl(url);
    } catch (_) {
      return profile.withAvatarUrl(null);
    }
  }

  /// Persists the customer's default drop-off for Profile settings and checkout autofill.
  ///
  /// Stored on the signed-in account. The live profiles table has no
  /// delivery_address column, and writing it raises PGRST204.
  static Future<Profile> saveDeliveryAddress({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final u = sb.auth.currentUser;
    if (u == null) throw StateError('Sign in to save your address');
    final trimmed = address.trim();
    if (trimmed.isEmpty) throw ArgumentError('Delivery address required');
    final data = Map<String, dynamic>.from(u.userMetadata ?? {});
    data['delivery_address'] = trimmed;
    data['delivery_lat'] = lat;
    data['delivery_lng'] = lng;
    await sb.auth.updateUser(UserAttributes(data: data));
    final row = await sb.from('profiles').select().eq('id', u.id).single();
    return Profile.fromMap(row).applyingMeta(data);
  }

  static Map<String, dynamic>? _metaMap(Object? meta) {
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return null;
  }

  static Future<List<Station>> stations() async => (await sb.from('stations').select().order('name')).map(Station.fromMap).toList();

  static Future<List<Category>> categories() async => (await sb.from('categories').select().order('sort')).map(Category.fromMap).toList();

  /// Stations with at least one available product in the category (e.g. 'rice').
  static Future<Set<String>> stationIdsWithCategory(String slug) async {
    final category = await sb.from('categories').select('id').eq('slug', slug).maybeSingle();
    if (category == null) return {};
    final rows = await sb.from('products').select('station_id').eq('category_id', category['id']).eq('is_available', true);
    return {for (final r in rows) r['station_id'] as String};
  }

  static Future<List<Product>> products(String stationId, {bool onlyAvailable = true}) async {
    var q = sb.from('products').select().eq('station_id', stationId);
    if (onlyAvailable) q = q.eq('is_available', true);
    return (await q.order('name')).map(Product.fromMap).toList();
  }

  /// Payment: COD now; 'gcash'/'maya' are accepted by the DB and can be wired
  /// to a payment gateway (e.g. PayMongo) via a Supabase Edge Function later.
  static Future<String> placeOrder({
    required String stationId,
    required Map<Product, int> cart,
    required String address,
    double? lat,
    double? lng,
    String? phone,
    String? notes,
    String payment = 'cod',
    required String requestId,
  }) async {
    final id = await sb.rpc(
      'place_order_idempotent',
      params: {
        'p_station': stationId,
        'p_items': cart.entries.map((e) => {'product_id': e.key.id, 'quantity': e.value}).toList(),
        'p_address': address,
        'p_lat': lat,
        'p_lng': lng,
        'p_phone': phone,
        'p_notes': notes,
        'p_payment': payment,
        'p_request_id': requestId,
      },
    );
    return id as String;
  }

  static Future<double> deliveryQuote(String stationId, double lat, double lng) async {
    final value = await sb.rpc('delivery_quote', params: {'p_station': stationId, 'p_lat': lat, 'p_lng': lng});
    return (value as num).toDouble();
  }

  static Future<List<Map<String, dynamic>>> stationReviews(String stationId) async =>
      List<Map<String, dynamic>>.from(await sb.from('station_reviews').select('rating, comment, created_at').eq('station_id', stationId).order('created_at', ascending: false).limit(30));

  static Future<void> submitReview(Order order, int rating, String comment) => sb.from('station_reviews').insert({
    'order_id': order.id, 'station_id': order.stationId, 'customer_id': order.customerId,
    'rating': rating, 'comment': comment.trim(),
  });

  static Future<Order?> orderById(String orderId) async {
    final row = await sb.from('orders').select(orderSelect).eq('id', orderId).maybeSingle();
    return row == null ? null : Order.fromMap(row);
  }

  static Stream<Order?> watchOrder(String orderId) =>
      sb.from('orders').stream(primaryKey: ['id']).eq('id', orderId).asyncMap((_) => orderById(orderId));


  static Stream<List<Order>> watchOrders({String? customerId, String? stationId}) {
    // Realtime stream keeps the list fresh; details (items/customer) are re-fetched.
    final col = customerId != null ? 'customer_id' : 'station_id';
    final val = customerId ?? stationId!;
    return sb.from('orders').stream(primaryKey: ['id']).eq(col, val).asyncMap((_) async {
      final rows = await sb.from('orders').select(orderSelect).eq(col, val).order('created_at', ascending: false).limit(100);
      return rows.map(Order.fromMap).toList();
    });
  }

  /// Supabase query builders are lazy: they only run when awaited, so every call here awaits.
  /// `.select()` makes a blocked/no-op update (0 rows) surface as an error instead of failing silently.
  static Future<void> setStatus(String orderId, String status) async {
    await sb.rpc('owner_set_order_status', params: {'p_order': orderId, 'p_status': status});
  }

  static Future<void> cancelOrder(String orderId) async {
    await sb.rpc('cancel_order', params: {'p_order': orderId});
  }

  /// Owner: save the rider and mark the order delivering.
  /// Returns a fresh secret link token. Saving the name and phone is what
  /// starts delivery; the rider does not have to tap Start delivery first.
  static Future<String> assignRider(String orderId, String name, String phone, {String? stationId}) async {
    final token = await sb.rpc('assign_rider', params: {
      'p_order': orderId,
      'p_name': name,
      'p_phone': phone,
    }) as String;
    await riderStatus(token, 'out_for_delivery');
    if (stationId != null) await rememberRider(stationId, name, phone);
    return token;
  }

  /// Riders this station has used before (saved list, else past order assignments).
  static Future<List<SavedRider>> stationRiders(String stationId) async {
    try {
      final rows = await sb
          .from('station_riders')
          .select('name, phone, last_used_at')
          .eq('station_id', stationId)
          .order('last_used_at', ascending: false)
          .limit(20);
      final saved = uniqueRidersByPhone(rows.map((r) => SavedRider.fromMap(Map<String, dynamic>.from(r))));
      if (saved.isNotEmpty) return saved;
    } catch (_) {
      /* Table may not be migrated yet; fall back to order history. */
    }
    final rows = await sb
        .from('orders')
        .select('rider_name, rider_phone, created_at')
        .eq('station_id', stationId)
        .not('rider_phone', 'is', null)
        .order('created_at', ascending: false)
        .limit(40);
    return uniqueRidersByPhone(rows.map((r) => SavedRider.fromMap(Map<String, dynamic>.from(r))));
  }

  /// Persist a rider for quick re-use on later orders. No-ops if the table is missing.
  static Future<void> rememberRider(String stationId, String name, String phone) async {
    final trimmed = name.trim();
    final normalized = normalizeRiderPhone(phone);
    if (trimmed.isEmpty || normalized.isEmpty) return;
    try {
      await sb.from('station_riders').upsert({
        'station_id': stationId,
        'name': trimmed,
        'phone': normalized,
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'station_id,phone');
    } catch (_) {
      /* Optional until the station_riders migration is applied. */
    }
  }

  static Future<String?> riderToken(String orderId) async =>
      (await sb.from('order_rider_links').select('token').eq('order_id', orderId).maybeSingle())?['token'] as String?;

  static String riderLink(String token) => '${AppConfig.appUrl}/#/rider/$token';

  // Rider (no login): every call is checked against the secret token in SQL.
  static Future<Map<String, dynamic>> riderOrder(String token) async =>
      Map<String, dynamic>.from(await sb.rpc('rider_get_order', params: {'p_token': token}));
  static Future<void> riderLocation(String token, double lat, double lng, double? heading) async {
    await sb.rpc('rider_update_location', params: {'p_token': token, 'p_lat': lat, 'p_lng': lng, 'p_heading': heading});
  }

  static Future<void> riderStatus(String token, String status) async {
    await sb.rpc('rider_set_status', params: {'p_token': token, 'p_status': status});
  }


  static Stream<Map<String, dynamic>?> watchRider(String orderId) =>
      sb.from('rider_locations').stream(primaryKey: ['order_id']).eq('order_id', orderId).map((rows) => rows.isEmpty ? null : rows.first);

  // Phone verification (Supabase phone OTP; needs an SMS provider in the dashboard)
  static Future<bool> requirePhoneVerification() async =>
      ((await sb.from('app_config').select('require_phone_verification').maybeSingle())?['require_phone_verification'] as bool?) ?? false;
  static bool get phoneVerified => sb.auth.currentUser?.phoneConfirmedAt != null;
  static String toE164(String ph) {
    final d = ph.replaceAll(RegExp(r'[^0-9+]'), '');
    if (d.startsWith('+')) return d;
    if (d.startsWith('0')) return '+63${d.substring(1)}';
    if (d.startsWith('63')) return '+$d';
    return '+63$d';
  }

  static Future<void> sendPhoneOtp(String phone) => sb.auth.updateUser(UserAttributes(phone: toE164(phone)));
  static Future<void> verifyPhoneOtp(String phone, String code) async {
    await sb.auth.verifyOTP(type: OtpType.phoneChange, phone: toE164(phone), token: code);
    await sb.auth.refreshSession();
  }

  // Owner applications
  static Future<List<OwnerApplication>> myApplications() async =>
      (await sb.from('owner_applications').select().eq('applicant_id', sb.auth.currentUser!.id).order('created_at', ascending: false))
          .map(OwnerApplication.fromMap)
          .toList();
  static Future<List<OwnerApplication>> applications(String status) async =>
      (await sb.from('owner_applications').select().eq('status', status).order('created_at')).map(OwnerApplication.fromMap).toList();
  static Future<String> uploadDoc(String name, Uint8List bytes, String contentType) async {
    final path = '${sb.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}_$name';
    await sb.storage.from('owner-docs').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return path;
  }

  /// Product photos live in the public `product-images` bucket under `<station_id>/` (owner-only writes via RLS).
  ///
  /// Paths are unique timestamps, so upsert is off. Upsert needs a storage SELECT
  /// policy that this bucket does not grant to owners, which made uploads fail.
  static Future<String> uploadProductImage(String stationId, Uint8List bytes, String ext, String contentType) async {
    final path = '$stationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await sb.storage.from('product-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
    return sb.storage.from('product-images').getPublicUrl(path);
  }

  /// Station profile photos live in the public `station-photos` bucket under `<station_id>/` (owner-only writes via RLS).
  ///
  /// Paths are unique timestamps, so upsert is off. Upsert needs a storage SELECT
  /// policy that this bucket does not grant to owners, which made uploads fail.
  static Future<String> uploadStationPhoto(String stationId, Uint8List bytes, String ext, String contentType) async {
    final path = '$stationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await sb.storage.from('station-photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
    return sb.storage.from('station-photos').getPublicUrl(path);
  }

  static Future<void> deleteStationPhoto(String? url) async {
    const marker = '/station-photos/';
    final i = url?.indexOf(marker) ?? -1;
    if (i < 0) return;
    try {
      await sb.storage.from('station-photos').remove([url!.substring(i + marker.length)]);
    } catch (_) {
      /* best effort */
    }
  }

  static Future<void> deleteProductImage(String url) async {
    const marker = '/product-images/';
    final i = url.indexOf(marker);
    if (i < 0 || url.contains('/defaults/')) return;
    try {
      await sb.storage.from('product-images').remove([url.substring(i + marker.length)]);
    } catch (_) {
      /* best effort */
    }
  }

  static Future<String> docUrl(String path) => sb.storage.from('owner-docs').createSignedUrl(path, 600);
  static Future<void> submitApplication(Map<String, dynamic> data) =>
      sb.from('owner_applications').insert({...data, 'applicant_id': sb.auth.currentUser!.id});
  static Future<void> approve(String id, String? notes) async {
    await sb.rpc('approve_owner_application', params: {'p_id': id, 'p_notes': notes});
  }

  static Future<void> reject(String id, String? notes) async {
    await sb.rpc('reject_owner_application', params: {'p_id': id, 'p_notes': notes});
  }

  static Future<List<Map<String, dynamic>>> sales(String stationId, DateTime from, DateTime to) async => List<Map<String, dynamic>>.from(
    await sb.rpc(
      'station_sales',
      params: {'p_station': stationId, 'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String()},
    ),
  );

  static Future<List<Map<String, dynamic>>> topProducts(String stationId, DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(
        await sb.rpc(
          'station_top_products',
          params: {'p_station': stationId, 'p_from': from.toUtc().toIso8601String(), 'p_to': to.toUtc().toIso8601String()},
        ),
      );
}
