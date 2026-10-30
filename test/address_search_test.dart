import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:refilly/services/address_search.dart';

void main() {
  const sample = {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [121.046, 14.635]},
    'properties': {
      'housenumber': '12',
      'street': 'Aurora Boulevard',
      'district': 'Cubao',
      'city': 'Quezon City',
      'state': 'Metro Manila',
    },
  };

  test('geocoding uses longitude/latitude GeoJSON order', () {
    final result = AddressSuggestion.fromPhotonFeature(sample);
    expect(result, isNotNull);
    expect(result!.latitude, 14.635);
    expect(result.longitude, 121.046);
    expect(result.label, contains('Cubao'));
    expect(result.label, contains('Aurora Boulevard'));
  });

  test('ignores incomplete and invalid geocoding coordinates', () {
    expect(AddressSuggestion.fromPhotonFeature({'geometry': {'coordinates': [121.0]}}), isNull);
    expect(AddressSuggestion.fromPhotonFeature({
      'geometry': {'coordinates': [200.0, 90.0]},
      'properties': {'city': 'Invalid'},
    }), isNull);
  });

  test('search queries Philippine locations only and parses results', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['q'], 'Cubao');
      expect(request.url.queryParameters['countrycode'], 'PH');
      expect(request.url.queryParameters['limit'], '5');
      return http.Response(jsonEncode({'features': [sample]}), 200);
    });
    final service = AddressSearchService(client: client);
    final results = await service.search('Cubao');
    expect(results, hasLength(1));
    expect(results.single.label, contains('Quezon City'));
    service.dispose();
  });

  test('does not query geocoder for very short input', () async {
    final client = MockClient((_) async => throw StateError('Unexpected network request'));
    final service = AddressSearchService(client: client);
    expect(await service.search('ab'), isEmpty);
    service.dispose();
  });
}
