import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';
import 'package:foxy_ads/features/real-estate/presentation/providers/re_search_provider.dart';

void main() {
  group('ReSearchFilters JSON round-trip', () {
    const original = ReSearchFilters(
      operation: 'venta',
      city: 'Madrid',
      propertyTypes: ['piso', 'atico'],
      priceMin: 100000,
      priceMax: 300000,
      rooms: [2, 3],
    );

    test('toJson -> fromJson yields an equal object', () {
      final restored = ReSearchFilters.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('toJson output contains the _kind discriminator', () {
      final json = original.toJson();
      expect(json['_kind'], 're');
    });

    test('fromJson tolerates an empty map (all defaults)', () {
      final restored = ReSearchFilters.fromJson(const {});
      expect(restored, equals(const ReSearchFilters()));
    });
  });

  group('SavedSearch backward compatibility', () {
    test('legacy row (no _kind) is not RE and parses SearchFilters', () {
      final row = {
        'id': 'legacy-1',
        'user_id': 'u1',
        'category_id': 'vehicles',
        'label': 'Coches Madrid',
        'query': jsonEncode({
          'query': 'coche',
          'categoryId': 'vehicles',
          'minPrice': 1000,
          'maxPrice': 20000,
          'sort': 'price_asc',
        }),
        'country_code': 'ES',
        'created_at': '2026-08-01T00:00:00Z',
        'last_seen_at': null,
      };

      final search = SavedSearch.fromRow(row);

      expect(search.isRealEstate, isFalse);
      expect(search.filters.query, 'coche');
      expect(search.filters.categoryId, 'vehicles');
      expect(search.filters.minPrice, 1000);
      expect(search.filters.maxPrice, 20000);
      expect(search.filters.sort, 'price_asc');
    });

    test('RE row (_kind: re) is recognized as real estate', () {
      const filters = ReSearchFilters(
        operation: 'alquiler',
        city: 'Barcelona',
        propertyTypes: ['piso'],
      );
      final row = {
        'id': 're-1',
        'user_id': 'u1',
        'category_id': null,
        'label': 'Piso Barcelona',
        'query': jsonEncode(filters.toJson()),
        'country_code': 'ES',
        'created_at': '2026-08-01T00:00:00Z',
        'last_seen_at': null,
      };

      final search = SavedSearch.fromRow(row);

      expect(search.isRealEstate, isTrue);
      final restored = ReSearchFilters.fromJson(search.rawQuery);
      expect(restored, equals(filters));
    });
  });
}
