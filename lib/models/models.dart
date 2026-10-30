double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

class Profile {
  final String id;
  final String? fullName, phone;
  final String role;
  Profile.fromMap(Map<String, dynamic> m) : id = m['id'], fullName = m['full_name'], phone = m['phone'], role = m['role'] ?? 'customer';
}

class Station {
  final String id, name;
  final String? ownerId, address, phone, description;
  final double lat, lng;
  final bool isOpen;
  Station.fromMap(Map<String, dynamic> m)
    : id = m['id'],
      name = m['name'],
      ownerId = m['owner_id'],
      address = m['address'],
      phone = m['phone'],
      description = m['description'],
      lat = _d(m['lat']),
      lng = _d(m['lng']),
      isOpen = m['is_open'] ?? true;
}

class Category {
  final String id, slug, name;
  Category.fromMap(Map<String, dynamic> m) : id = m['id'], slug = m['slug'], name = m['name'];
}

class Product {
  final String id, stationId, name, unit;
  final String? categoryId, description, imageUrl;
  final double price;
  final bool isAvailable;
  Product.fromMap(Map<String, dynamic> m)
    : id = m['id'],
      stationId = m['station_id'],
      name = m['name'],
      unit = m['unit'] ?? 'pc',
      categoryId = m['category_id'],
      description = m['description'],
      imageUrl = m['image_url'],
      price = _d(m['price']),
      isAvailable = m['is_available'] ?? true;
}

class OrderItem {
  final String productName;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;
  OrderItem.fromMap(Map<String, dynamic> m)
    : productName = m['product_name'],
      imageUrl = (m['product'] as Map?)?['image_url'],
      unitPrice = _d(m['unit_price']),
      quantity = m['quantity'];
}

const orderStatuses = ['pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'];
String statusLabel(String s) => s.replaceAll('_', ' ').toUpperCase();

class Order {
  final String id, customerId, stationId, status, deliveryAddress, paymentMethod, paymentStatus;
  final String? riderName, riderPhone, contactPhone, notes;
  final double? deliveryLat, deliveryLng;
  final double total;
  final DateTime createdAt;
  final List<OrderItem> items;
  final Map<String, dynamic>? customer, station;
  Order.fromMap(Map<String, dynamic> m)
    : id = m['id'],
      customerId = m['customer_id'],
      stationId = m['station_id'],
      status = m['status'],
      deliveryAddress = m['delivery_address'] ?? '',
      paymentMethod = m['payment_method'] ?? 'cod',
      paymentStatus = m['payment_status'] ?? 'unpaid',
      riderName = m['rider_name'],
      riderPhone = m['rider_phone'],
      contactPhone = m['contact_phone'],
      notes = m['notes'],
      deliveryLat = (m['delivery_lat'] as num?)?.toDouble(),
      deliveryLng = (m['delivery_lng'] as num?)?.toDouble(),
      total = _d(m['total']),
      createdAt = DateTime.parse(m['created_at']).toLocal(),
      items = ((m['order_items'] as List?) ?? []).map((e) => OrderItem.fromMap(e)).toList(),
      customer = m['customer'],
      station = m['station'];
}

class OwnerApplication {
  final String id, applicantId, businessName, stationName, address, permitPath, photoPath, status;
  final String? phone, notes;
  final double lat, lng;
  final DateTime createdAt;
  OwnerApplication.fromMap(Map<String, dynamic> m)
    : id = m['id'],
      applicantId = m['applicant_id'],
      businessName = m['business_name'],
      stationName = m['station_name'],
      address = m['address'],
      permitPath = m['permit_path'],
      photoPath = m['photo_path'],
      status = m['status'],
      phone = m['phone'],
      notes = m['notes'],
      lat = _d(m['lat']),
      lng = _d(m['lng']),
      createdAt = DateTime.parse(m['created_at']).toLocal();
}
