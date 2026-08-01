import '../../../core/models/listing_model.dart';

class DayPoint {
  final String day;
  final int views;
  const DayPoint(this.day, this.views);
}

class PanelStats {
  final int total;
  final int active;
  final int sold;
  final int views;
  final int featured;
  final int favorites;

  const PanelStats({
    required this.total,
    required this.active,
    required this.sold,
    required this.views,
    required this.featured,
    required this.favorites,
  });
}

/// "Currently featured" means `is_featured=true` AND (`featured_until` is
/// null/never expires OR `featured_until` is still in the future). The web
/// applies the same rule in `computePanelStats` (see `src/lib/panel.ts`).
///
/// Note: `Listing.isFeatured` is a non-nullable `bool` (default false) and
/// `Listing.featuredUntil` is a parsed `DateTime?` — these differ from the
/// brief's template assumptions, so we adapt the accessors here.
bool _isCurrentlyFeatured(Listing l, DateTime now) {
  if (!l.isFeatured) return false;
  final until = l.featuredUntil;
  if (until == null) return true; // no expiry -> counts
  return until.isAfter(now);
}

/// Pure aggregation over a row of listings for the agency dashboard header.
/// `favByListing` is the precomputed `{listingId: favCount}` map (already
/// fetched separately by the panel screen). `now` is injected so tests can
/// pin "today" without monkey-patching the clock.
PanelStats computePanelStats(
  List<Listing> rows,
  Map<String, int> favByListing,
  DateTime now,
) {
  var active = 0;
  var sold = 0;
  var views = 0;
  var featured = 0;
  var favorites = 0;
  for (final r in rows) {
    if (r.status == 'active') active++;
    if (r.status == 'sold') sold++;
    views += r.views; // non-nullable int
    favorites += favByListing[r.id] ?? 0;
    if (_isCurrentlyFeatured(r, now)) featured++;
  }
  return PanelStats(
    total: rows.length,
    active: active,
    sold: sold,
    views: views,
    featured: featured,
    favorites: favorites,
  );
}
