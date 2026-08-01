import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';

void main() {
  test('SavedSearch.fromRow parses the query JSON into filters', () {
    final row = {
      'id': 'abc',
      'user_id': 'u1',
      'category_id': 'vehicles',
      'label': 'Coches Madrid',
      'query': jsonEncode({'query': 'coche', 'sort': 'newest'}),
      'country_code': 'ES',
      'created_at': '2026-08-01T00:00:00Z',
      'last_seen_at': null,
    };
    final s = SavedSearch.fromRow(row);
    expect(s.id, 'abc');
    expect(s.label, 'Coches Madrid');
    expect(s.filters.query, 'coche');
    expect(s.countryCode, 'ES');
    expect(s.lastSeenAt, isNull);
  });
}
