/// A rider name + phone the station owner has used before.
class SavedRider {
  final String name;
  final String phone;
  const SavedRider({required this.name, required this.phone});

  String get normalizedPhone => normalizeRiderPhone(phone);

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};

  factory SavedRider.fromMap(Map<String, dynamic> m) => SavedRider(
    name: (m['name'] ?? m['rider_name'] ?? '').toString().trim(),
    phone: normalizeRiderPhone((m['phone'] ?? m['rider_phone'] ?? '').toString()),
  );
}

/// Philippine mobiles to a comparable 11-digit 09XXXXXXXXX form.
String normalizeRiderPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('63') && digits.length == 12) digits = '0${digits.substring(2)}';
  if (digits.startsWith('9') && digits.length == 10) digits = '0$digits';
  return digits;
}

/// Keep the newest name for each phone. [rows] should already be newest-first.
List<SavedRider> uniqueRidersByPhone(Iterable<SavedRider> rows, {int limit = 12}) {
  final seen = <String>{};
  final out = <SavedRider>[];
  for (final rider in rows) {
    if (rider.name.isEmpty || rider.normalizedPhone.isEmpty) continue;
    if (!seen.add(rider.normalizedPhone)) continue;
    out.add(SavedRider(name: rider.name, phone: rider.normalizedPhone));
    if (out.length >= limit) break;
  }
  return out;
}
