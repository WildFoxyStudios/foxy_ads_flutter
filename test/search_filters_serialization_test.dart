import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/features/search/presentation/providers/search_filters_provider.dart';

void main() {
  test('SearchFilters round-trips through JSON', () {
    const f = SearchFilters(
      query: 'piso madrid',
      categoryId: 'real_estate',
      minPrice: 100,
      maxPrice: 500000,
      sort: 'price_asc',
    );
    final restored = SearchFilters.fromJson(f.toJson());
    expect(restored, f);
  });

  test('fromJson tolerates missing keys with defaults', () {
    final f = SearchFilters.fromJson(const {});
    expect(f.query, '');
    expect(f.sort, 'newest');
    expect(f.categoryId, isNull);
    expect(f.minPrice, isNull);
    expect(f.maxPrice, isNull);
  });
}
