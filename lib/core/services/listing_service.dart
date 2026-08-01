import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing_model.dart';
import '../models/category_model.dart';
import '../providers/supabase_provider.dart';
import '../../features/real-estate/data/re_models.dart';
import '../../features/real-estate/data/re_pricing.dart';

final listingServiceProvider = Provider<ListingService>((ref) {
  return ListingService(ref.watch(supabaseClientProvider));
});

class ListingService {
  final SupabaseClient _supabase;

  ListingService(this._supabase);

  // Get listings with filters
  Future<List<Listing>> getListings({
    String? countryCode,
    String? categoryId,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String? city,
    bool featuredFirst = true,
    int limit = 20,
    int offset = 0,
  }) async {
    PostgrestFilterBuilder query = _supabase
        .from('listings')
        .select('''
          *,
          users(name, avatar_url),
          categories!listings_category_id_fkey(name)
        ''')
        .eq('status', 'active');

    if (countryCode != null) {
      query = query.eq('country_code', countryCode);
    }

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or(
        'title.ilike.%$searchQuery%,description.ilike.%$searchQuery%',
      );
    }

    if (minPrice != null) {
      query = query.gte('price', minPrice);
    }

    if (maxPrice != null) {
      query = query.lte('price', maxPrice);
    }

    if (city != null && city.isNotEmpty) {
      query = query.ilike('city', '%$city%');
    }

    // Apply ordering and pagination
    PostgrestTransformBuilder orderedQuery;
    if (featuredFirst) {
      orderedQuery = query
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false);
    } else {
      orderedQuery = query.order('created_at', ascending: false);
    }

    final response = await orderedQuery.range(offset, offset + limit - 1);

    return (response as List).map((json) {
      final userData = json['users'] as Map<String, dynamic>?;
      final categoryData = json['categories'] as Map<String, dynamic>?;

      return Listing.fromJson({
        ...json,
        'user_name': userData?['name'],
        'user_avatar': userData?['avatar_url'],
        'category_name': categoryData?['name'],
      });
    }).toList();
  }

  // Get featured listings
  Future<List<Listing>> getFeaturedListings({
    String? countryCode,
    int limit = 10,
  }) async {
    var query = _supabase
        .from('listings')
        .select('''
          *,
          users(name, avatar_url),
          categories!listings_category_id_fkey(name)
        ''')
        .eq('status', 'active')
        .eq('is_featured', true)
        .gt('featured_until', DateTime.now().toIso8601String());

    if (countryCode != null) {
      query = query.eq('country_code', countryCode);
    }

    final response = await query
        .order('featured_until', ascending: false)
        .limit(limit);

    return (response as List).map((json) {
      final userData = json['users'] as Map<String, dynamic>?;
      final categoryData = json['categories'] as Map<String, dynamic>?;

      return Listing.fromJson({
        ...json,
        'user_name': userData?['name'],
        'user_avatar': userData?['avatar_url'],
        'category_name': categoryData?['name'],
      });
    }).toList();
  }

  // Get listing by ID
  Future<Listing?> getListingById(String id) async {
    try {
      final response = await _supabase
          .from('listings')
          .select('''
            *,
            users(name, avatar_url),
            categories!listings_category_id_fkey(name)
          ''')
          .eq('id', id)
          .single();

      final userData = response['users'] as Map<String, dynamic>?;
      final categoryData = response['categories'] as Map<String, dynamic>?;

      // Increment views atomically via the SECURITY DEFINER RPC. A direct
      // UPDATE here was both racy (lost concurrent increments) and blocked by
      // RLS for non-owners — only the owner may UPDATE a listing — so views
      // from actual visitors were never counted. It also needlessly bumped
      // updated_at on every view.
      await _supabase.rpc(
        'increment_listing_views',
        params: {'listing_uuid': id},
      );

      return Listing.fromJson({
        ...response,
        'user_name': userData?['name'],
        'user_avatar': userData?['avatar_url'],
        'category_name': categoryData?['name'],
      });
    } catch (e) {
      return null;
    }
  }

  // Get user's listings
  Future<List<Listing>> getUserListings(String userId) async {
    final response = await _supabase
        .from('listings')
        .select('''
          *,
          categories!listings_category_id_fkey(name)
        ''')
        .eq('user_id', userId)
        .neq('status', 'deleted')
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final categoryData = json['categories'] as Map<String, dynamic>?;

      return Listing.fromJson({
        ...json,
        'category_name': categoryData?['name'],
      });
    }).toList();
  }

  // Create listing. `extraFields` is merged into the insert payload
  // after `toInsertJson()` — used to pass the `attributes` JSONB column
  // for real-estate listings (the `Listing` model intentionally has no
  // `attributes` field; the form encodes the map and hands it here).
  Future<Listing> createListing(
    Listing listing, {
    Map<String, dynamic>? extraFields,
  }) async {
    final payload = <String, dynamic>{
      ...listing.toInsertJson(),
      if (extraFields != null) ...extraFields,
    };
    final response = await _supabase
        .from('listings')
        .insert(payload)
        .select()
        .single();

    return Listing.fromJson(response);
  }

  // Update listing
  Future<void> updateListing(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    await _supabase.from('listings').update(updates).eq('id', id);
  }

  // Delete listing
  Future<void> deleteListing(String id) async {
    await _supabase.from('listings').update({'status': 'deleted'}).eq('id', id);
  }

  // Promote listing (make featured). Now takes the price in cents so the caller
  // is responsible for unit conversion (matches the web's FEATURE_PRICES table).
  Future<void> promoteListing({
    required String id,
    required int days,
    required int priceCents,
  }) async {
    // Use the hardened SECURITY DEFINER RPC instead of a raw UPDATE: it
    // validates the day range, enforces that the caller owns the listing, and
    // extends `featured_until` atomically (stacking onto an existing feature
    // window rather than overwriting it). The old raw UPDATE also flipped
    // `is_negotiable` to false as an unrelated side effect — that bug is gone.
    // The amount paid is recorded separately in `payments` by the Stripe webhook.
    await _supabase.rpc(
      'promote_listing',
      params: {'listing_uuid': id, 'days': days},
    );
  }

  // Upload images
  Future<List<String>> uploadImages(String userId, List<dynamic> images) async {
    final List<String> urls = [];

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      // Upload into the user's own folder ("$userId/...") so the folder-scoped
      // storage RLS policy accepts it. A flat "${userId}_..." name only passed
      // via the loose "any authenticated" policy and blocked the owner from
      // ever deleting/replacing their own image.
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      await _supabase.storage.from('listings').uploadBinary(fileName, image);

      final url = _supabase.storage.from('listings').getPublicUrl(fileName);
      urls.add(url);
    }

    return urls;
  }

  // Get categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('sort_order');

      return (response as List).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      // Return default categories if database fetch fails
      return Category.defaultCategories;
    }
  }

  // Get main categories only (no subcategories)
  Future<List<Category>> getMainCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .isFilter('parent_id', null)
          .order('sort_order');

      return (response as List).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      return Category.defaultCategories.where((c) => c.isMainCategory).toList();
    }
  }

  // Get categories with their subcategories
  Future<List<Category>> getCategoriesWithSubcategories() async {
    try {
      // Get all categories
      final response = await _supabase
          .from('categories')
          .select()
          .order('sort_order');

      final allCategories = (response as List)
          .map((json) => Category.fromJson(json))
          .toList();

      // Separate main categories and subcategories
      final mainCategories = allCategories
          .where((c) => c.parentId == null)
          .toList();
      final subcategories = allCategories
          .where((c) => c.parentId != null)
          .toList();

      // Attach subcategories to their parent categories
      return mainCategories.map((main) {
        final subs = subcategories.where((s) => s.parentId == main.id).toList();
        return main.copyWithSubcategories(subs);
      }).toList();
    } catch (e) {
      return Category.defaultCategories.where((c) => c.isMainCategory).toList();
    }
  }

  /// Full-text search via the `search_listings` RPC. Uses the `tsvector`
  /// `search_vector` column with the GIN index, applies locale-aware ranking
  /// (the `p_locale` parameter shapes the text-search config so ES/EN/IT
  /// accents and stop-words are handled correctly), and supports structured
  /// filters as JSON. This replaces the old `ilike %q%` approach which
  /// couldn't use the index and missed accent-folding.
  ///
  /// The RPC returns `{ items: [...], total: <n> }`. Each item includes
  /// `headline` (highlighted snippet) — currently ignored; the list cards use
  /// `title`. `user_name` / `category_name` are not returned (no joins in the
  /// RPC) and will be null in the resulting `Listing` objects; the existing
  /// null-tolerant code paths handle this.
  Future<List<Listing>> searchListings({
    required String query,
    String locale = 'es',
    String? countryCode,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String sort = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    final filters = <String, dynamic>{};
    if (countryCode != null) filters['country_code'] = countryCode;
    if (categoryId != null) filters['category_id'] = categoryId;
    if (minPrice != null) filters['min_price'] = minPrice;
    if (maxPrice != null) filters['max_price'] = maxPrice;

    final response = await _supabase.rpc(
      'search_listings',
      params: {
        'p_query': query,
        'p_locale': locale,
        'p_filters': filters,
        'p_offset': offset,
        'p_limit': limit,
        'p_sort': sort,
      },
    );

    final body = response is Map<String, dynamic>
        ? response
        : (response as List).firstOrNull as Map<String, dynamic>?;
    if (body == null) return const [];
    final items = (body['items'] as List<dynamic>?) ?? const [];
    return items
        .map((json) => Listing.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Search suggestions
  Future<List<String>> getSearchSuggestions(
    String query, {
    String? countryCode,
  }) async {
    var dbQuery = _supabase
        .from('listings')
        .select('title')
        .eq('status', 'active')
        .ilike('title', '%$query%');

    if (countryCode != null) {
      dbQuery = dbQuery.eq('country_code', countryCode);
    }

    final response = await dbQuery.limit(10);

    return (response as List)
        .map((item) => item['title'] as String)
        .toSet()
        .toList();
  }

  /// Real-estate search via the `search_real_estate` RPC. Returns the page of
  /// `Listing`s plus the unpaginated head-count `total` so the caller (T4
  /// search screen) can render "showing N of M" and drive pagination. The RPC
  /// returns `{items: [...], total: <n>}` — same envelope shape as
  /// `searchListings` exposes, and `Listing.fromJson` already tolerates the
  /// missing `user_name` / `category_name` joins that the RPC omits.
  ///
  /// `total` falls back to `items.length` if the RPC omits or nulls the count
  /// key (matches the web's defensive `Number(rows[0].total_count) || 0`).
  ///
  /// `offset` is 0-based (matches `searchListings`). `limit` defaults to 24
  /// (the web's `RE_SEARCH_DEFAULT_PAGE_SIZE`).
  Future<({List<Listing> items, int total})> searchRealEstate(
    ReFilters f, {
    int offset = 0,
    int limit = 24,
  }) async {
    final response = await _supabase.rpc(
      'search_real_estate',
      params: buildReRpcArgs(f, offset, limit),
    );

    final body = response is Map<String, dynamic>
        ? response
        : (response as List).firstOrNull as Map<String, dynamic>?;
    if (body == null) return (items: <Listing>[], total: 0);
    final items = (body['items'] as List<dynamic>?) ?? const [];
    final listingList = items
        .map((json) => Listing.fromJson(json as Map<String, dynamic>))
        .toList();
    final totalRaw = body['total'];
    int total = listingList.length;
    if (totalRaw is num) {
      total = totalRaw.toInt();
    } else if (totalRaw is String) {
      final parsed = int.tryParse(totalRaw);
      if (parsed != null) total = parsed;
    }
    return (items: listingList, total: total);
  }

  /// Per-facet result counts for the real-estate filter drawer. Calls the
  /// `real_estate_facet_counts` RPC with the same filter args as the search
  /// RPC (the facet RPC ignores `p_sort`/`p_limit`/`p_offset`). Returns an
  /// empty `ReFacetCounts` on any RPC error so callers render their fallback
  /// facet list instead of crashing — same convention as the web's
  /// `fetchRealEstateFacetCounts`.
  Future<ReFacetCounts> reFacetCounts(ReFilters f) async {
    try {
      final response = await _supabase.rpc(
        'real_estate_facet_counts',
        params: buildReRpcArgs(f, 0, 0),
      );
      final row = response is Map<String, dynamic>
          ? response
          : (response as List).firstOrNull as Map<String, dynamic>?;
      if (row == null) return const ReFacetCounts();
      return ReFacetCounts(
        propertyType: (row['property_type_counts'] as Map?)?.cast<String, int>() ?? const {},
        condition: (row['condition_counts'] as Map?)?.cast<String, int>() ?? const {},
      );
    } catch (_) {
      return const ReFacetCounts();
    }
  }

  /// City-level average €/m² for the "zone price" widget on the listing
  /// detail. Mirrors the web's `fetchCityPriceStats`: queries `listings`
  /// where `category_id='real_estate'`, `status='active'`, same
  /// `country_code`/`city`, optionally same `attributes->>operation`, and
  /// computes the per-m² avg over up to 2000 active rows.
  ///
  /// Returns `null` when fewer than `minSample` rows produce a usable
  /// per-m² value (the web uses 3 as the default — below that, the avg is
  /// too noisy to display). `null` is also returned on RPC error so the
  /// listing-detail widget can hide the badge.
  Future<({double avgPricePerM2, int sampleSize})?> estimateFromCityStats({
    required String countryCode,
    required String city,
    String? operation,
    required int minSample,
  }) async {
    if (city.isEmpty) return null;
    try {
      // Filter first (returns PostgrestFilterBuilder with .eq available),
      // then apply .limit at the end — `.limit()` returns a
      // PostgrestTransformBuilder which has no `.eq`, so chaining the
      // operation filter after `.limit()` would fail to compile. Mirrors
      // the web's `fetchCityPriceStats` ordering.
      var query = _supabase
          .from('listings')
          .select('price, attributes')
          .eq('category_id', 'real_estate')
          .eq('status', 'active')
          .eq('country_code', countryCode)
          .eq('city', city);

      if (operation != null && operation.isNotEmpty) {
        query = query.eq('attributes->>operation', operation);
      }

      final response = await query.limit(2000);
      final rows = response as List<dynamic>? ?? const [];
      final perM2 = <num>[];
      for (final raw in rows) {
        final row = raw as Map<String, dynamic>;
        final price = row['price'] as num?;
        final attrs = row['attributes'] as Map<String, dynamic>?;
        final m2 = attrs?['m2'] as num?;
        final v = pricePerM2(price ?? double.nan, m2);
        if (v != null) perM2.add(v);
      }
      if (perM2.length < minSample) return null;
      final avg = perM2.fold<num>(0, (s, v) => s + v) / perM2.length;
      return (avgPricePerM2: avg.toDouble(), sampleSize: perM2.length);
    } catch (_) {
      return null;
    }
  }
}

/// Maps a typed `ReFilters` + page into the exact `p_*` argument names the
/// `search_real_estate` RPC expects (see the web's `buildRpcArgs` in
/// `src/lib/real-estate/search.ts` for the canonical mapping). Empty
/// multi-selects and unset scalars become `null` (Postgres "no filter"),
/// never `[]` — supabase-js drops `undefined` keys and an empty array
/// would filter out every row instead of meaning "any".
///
/// `energyLetter` is translated into a single-element `p_energy_bands`
/// array via `energyBandForLetter` so the UI's letter selection
/// (A..G) and the search RPC's band buckets (`alta`/`media`/`baja`) stay
/// decoupled.
///
/// Exported as a TOP-LEVEL function (not a method on `ListingService`) so
/// it can be unit-tested without a `SupabaseClient` instance.
Map<String, dynamic> buildReRpcArgs(
  ReFilters f,
  int offset,
  int limit,
) {
  final safeLimit = limit < 1 ? 1 : limit;
  final safeOffset = offset < 0 ? 0 : offset;
  final energyBands = <String>[
    ...f.energyBands,
    if (energyBandForLetter(f.energyLetter) case final band?) band,
  ];
  return {
    'p_country_code': f.countryCode,
    'p_state': f.state,
    'p_city': f.city,
    'p_operation': f.operation,
    'p_property_types': f.propertyTypes.isEmpty ? null : f.propertyTypes,
    'p_price_min': f.priceMin,
    'p_price_max': f.priceMax,
    'p_m2_min': f.m2Min,
    'p_m2_max': f.m2Max,
    'p_rooms': f.rooms.isEmpty ? null : f.rooms,
    'p_bathrooms': f.bathrooms.isEmpty ? null : f.bathrooms,
    'p_condition': f.conditions.isEmpty ? null : f.conditions,
    'p_features': f.features.isEmpty ? null : f.features,
    'p_floor_buckets': f.floorBuckets.isEmpty ? null : f.floorBuckets,
    'p_energy_bands': energyBands.isEmpty ? null : energyBands,
    'p_orientation': f.orientation.isEmpty ? null : f.orientation,
    'p_pets_allowed': f.petsAllowed,
    'p_posted_within_days': f.postedWithinDays,
    'p_sort': f.sort.toRpcString(),
    'p_limit': safeLimit,
    'p_offset': safeOffset,
  };
}
