import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

SupabaseClient get sb => Supabase.instance.client;

const orderSelect = '*, order_items(*), customer:profiles!orders_customer_id_fkey(full_name, phone), station:stations(name, lat, lng)';

class Api {
  static Future<Profile?> me() async {
    final u = sb.auth.currentUser;
    if (u == null) return null;
    final r = await sb.from('profiles').select().eq('id', u.id).maybeSingle();
    return r == null ? null : Profile.fromMap(r);
  }

  static Future<List<Station>> stations() async =>
      (await sb.from('stations').select().order('name')).map(Station.fromMap).toList();

  static Future<List<Category>> categories() async =>
      (await sb.from('categories').select().order('sort')).map(Category.fromMap).toList();

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
  }) async {
    final id = await sb.rpc('place_order', params: {
      'p_station': stationId,
      'p_items': cart.entries.map((e) => {'product_id': e.key.id, 'quantity': e.value}).toList(),
      'p_address': address,
      'p_lat': lat,
      'p_lng': lng,
      'p_phone': phone,
      'p_notes': notes,
      'p_payment': payment,
    });
    return id as String;
  }

  static Stream<List<Order>> watchOrders({String? customerId, String? stationId, String? riderId}) {
    // Realtime stream keeps the list fresh; details (items/customer) are re-fetched.
    final col = customerId != null ? 'customer_id' : stationId != null ? 'station_id' : 'rider_id';
    final val = customerId ?? stationId ?? riderId!;
    return sb.from('orders').stream(primaryKey: ['id']).eq(col, val).asyncMap((_) async {
      final rows = await sb.from('orders').select(orderSelect).eq(col, val).order('created_at', ascending: false).limit(100);
      return rows.map(Order.fromMap).toList();
    });
  }

  static Future<void> setStatus(String orderId, String status) =>
      sb.from('orders').update({'status': status, if (status == 'delivered') 'payment_status': 'paid'}).eq('id', orderId);

  static Future<void> assignRider(String orderId, String riderId) =>
      sb.from('orders').update({'rider_id': riderId}).eq('id', orderId);

  static Future<List<Profile>> riders(String stationId) async =>
      (await sb.from('profiles').select().eq('role', 'rider').eq('station_id', stationId)).map(Profile.fromMap).toList();

  static Future<bool> addRiderByPhone(String stationId, String phone) async {
    final r = await sb.from('profiles').update({'station_id': stationId}).eq('role', 'rider').eq('phone', phone).isFilter('station_id', null).select();
    return r.isNotEmpty;
  }

  static Future<void> pushLocation(String orderId, double lat, double lng, double? heading) => sb.from('rider_locations').upsert({
        'rider_id': sb.auth.currentUser!.id,
        'order_id': orderId,
        'lat': lat,
        'lng': lng,
        'heading': heading,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  static Stream<Map<String, dynamic>?> watchRider(String riderId) => sb
      .from('rider_locations')
      .stream(primaryKey: ['rider_id'])
      .eq('rider_id', riderId)
      .map((rows) => rows.isEmpty ? null : rows.first);

  static Future<List<Map<String, dynamic>>> sales(String stationId, DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(await sb.rpc('station_sales', params: {
        'p_station': stationId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }));

  static Future<List<Map<String, dynamic>>> topProducts(String stationId, DateTime from, DateTime to) async =>
      List<Map<String, dynamic>>.from(await sb.rpc('station_top_products', params: {
        'p_station': stationId,
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
      }));
}
