import 'dart:convert';

import 'package:http/http.dart' as http;

/// A forward-geocoded address and its suggested map coordinates.
class AddressSuggestion {
  const AddressSuggestion({required this.label, required this.latitude, required this.longitude});

  final String label;
  final double latitude;
  final double longitude;

  static AddressSuggestion? fromPhotonFeature(Object? value) {
    if (value is! Map) return null;
    final geometry = value['geometry'];
    final props = value['properties'];
    if (geometry is! Map || props is! Map) return null;
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = coords[0];
    final lat = coords[1];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return null;
    }

    String field(String key) => (props[key] is String ? props[key] as String : '').trim();
    final street = [field('housenumber'), field('street')].where((s) => s.isNotEmpty).join(' ');
    final parts = [
      if (field('name').isNotEmpty && field('name') != field('street')) field('name'),
      if (street.isNotEmpty) street,
      if (field('district').isNotEmpty) field('district'),
      if (field('city').isNotEmpty) field('city'),
      if (field('state').isNotEmpty) field('state'),
      if (field('postcode').isNotEmpty) field('postcode'),
    ];
    final distinct = <String>[];
    for (final p in parts) {
      if (!distinct.any((existing) => existing.toLowerCase() == p.toLowerCase())) distinct.add(p);
    }
    if (distinct.isEmpty) return null;
    return AddressSuggestion(label: distinct.join(', '), latitude: lat.toDouble(), longitude: lon.toDouble());
  }
}

/// Uses the Photon OpenStreetMap geocoder for low-volume address suggestions.
/// Its public endpoint is best-effort; production traffic should use a
/// dedicated/self-hosted geocoder. There is no guaranteed SLA.
class AddressSearchService {
  AddressSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AddressSuggestion>> search(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 3) return const [];
    final uri = Uri.https('photon.komoot.io', '/api', {
      'q': query,
      'limit': '5',
      'countrycode': 'PH',
      'lang': 'en',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Address lookup unavailable');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['features'] is! List) return const [];
    return (body['features'] as List)
        .map(AddressSuggestion.fromPhotonFeature)
        .whereType<AddressSuggestion>()
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
