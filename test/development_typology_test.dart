import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/developments/data/development_model.dart';

Listing _unit({required double price, Map<String, dynamic>? attrs}) => Listing(
      id: 'u', userId: 'a', categoryId: 'real_estate', countryCode: 'ES',
      title: 't', description: 'd', price: price, images: const [],
      createdAt: DateTime(2026), attributes: attrs,
    );

void main() {
  test('empty units → empty typologies', () {
    expect(aggregateTypologies([]), isEmpty);
  });
  test('buckets by rooms, min price, m2 range, sorted asc', () {
    final t = aggregateTypologies([
      _unit(price: 200000, attrs: {'rooms': '2', 'm2': '70'}),
      _unit(price: 180000, attrs: {'rooms': '2', 'm2': '65'}),
      _unit(price: 300000, attrs: {'rooms': '3', 'm2': '90'}),
    ]);
    expect(t.length, 2);
    expect(t[0].rooms, 2);
    expect(t[0].count, 2);
    expect(t[0].priceFrom, 180000);
    expect(t[0].m2Min, 65);
    expect(t[0].m2Max, 70);
    expect(t[1].rooms, 3);
  });
  test('units without rooms are skipped', () {
    expect(aggregateTypologies([_unit(price: 1, attrs: {'m2': '50'})]), isEmpty);
    expect(aggregateTypologies([_unit(price: 1, attrs: null)]), isEmpty);
  });
}
