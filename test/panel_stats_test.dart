import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/agency/data/panel_stats.dart';

// Build Listing fixtures via Listing.fromJson with the minimal keys the
// aggregation reads: status, views, is_featured, featured_until, id.
Listing _l(
    {required String id,
    required String status,
    int views = 0,
    bool featured = false,
    String? featuredUntil}) {
  return Listing.fromJson({
    'id': id,
    'user_id': 'u',
    'category_id': 'c',
    'country_code': 'ES',
    'title': 't',
    'description': 'd',
    'price': 1,
    'currency': 'EUR',
    'images': <String>[],
    'status': status,
    'views': views,
    'is_featured': featured,
    'featured_until': featuredUntil,
    'created_at': '2026-01-01T00:00:00Z',
  });
}

void main() {
  test('computePanelStats aggregates correctly with featured expiry', () {
    final now = DateTime.parse('2026-06-01T00:00:00Z');
    final rows = [
      _l(
          id: 'a',
          status: 'active',
          views: 5,
          featured: true,
          featuredUntil: '2026-12-01T00:00:00Z'),
      _l(
          id: 'b',
          status: 'active',
          views: 3,
          featured: true,
          featuredUntil: '2026-01-01T00:00:00Z'), // expired
      _l(id: 'c', status: 'sold', views: 2, featured: true), // no expiry -> counts
    ];
    final favs = {'a': 4, 'c': 1};
    final s = computePanelStats(rows, favs, now);
    expect(s.total, 3);
    expect(s.active, 2);
    expect(s.sold, 1);
    expect(s.views, 10);
    expect(s.featured, 2); // a (future) + c (no expiry); b expired
    expect(s.favorites, 5);
  });
}
