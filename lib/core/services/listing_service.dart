import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing_model.dart';
import '../models/category_model.dart';
import '../providers/supabase_provider.dart';

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

  // Create listing
  Future<Listing> createListing(Listing listing) async {
    final response = await _supabase
        .from('listings')
        .insert(listing.toInsertJson())
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
}
