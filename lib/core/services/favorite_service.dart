import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing_model.dart';
import 'auth_service.dart';

final favoriteServiceProvider = Provider<FavoriteService>((ref) {
  return FavoriteService();
});

final userFavoritesProvider = FutureProvider<List<String>>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return [];
      final favoriteService = ref.read(favoriteServiceProvider);
      return await favoriteService.getUserFavoriteIds(user.id);
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

class FavoriteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add to favorites
  Future<void> addFavorite(String userId, String listingId) async {
    await _supabase.from('favorites').insert({
      'user_id': userId,
      'listing_id': listingId,
    });
  }

  // Remove from favorites
  Future<void> removeFavorite(String userId, String listingId) async {
    await _supabase
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('listing_id', listingId);
  }

  // Toggle favorite
  Future<bool> toggleFavorite(String userId, String listingId) async {
    final isFavorite = await isFavorited(userId, listingId);

    if (isFavorite) {
      await removeFavorite(userId, listingId);
      return false;
    } else {
      await addFavorite(userId, listingId);
      return true;
    }
  }

  // Check if listing is favorited
  Future<bool> isFavorited(String userId, String listingId) async {
    final response = await _supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('listing_id', listingId)
        .maybeSingle();

    return response != null;
  }

  // Get user's favorite listing IDs
  Future<List<String>> getUserFavoriteIds(String userId) async {
    final response = await _supabase
        .from('favorites')
        .select('listing_id')
        .eq('user_id', userId);

    return (response as List)
        .map((item) => item['listing_id'] as String)
        .toList();
  }

  // Get user's favorite listings
  Future<List<Listing>> getUserFavorites(String userId) async {
    // NOTE: the nested users/categories joins must NOT be `!inner`. Favorites
    // are almost always OTHER people's listings, and the users RLS hides other
    // profiles — an inner join would drop the row entirely and the favorites
    // screen would appear empty. Regular (nullable) joins keep the listing and
    // just leave owner name/avatar null. `listings!inner` stays so the
    // `listings.status = active` filter works.
    final response = await _supabase
        .from('favorites')
        .select('''
          listing_id,
          listings!inner(
            *,
            users(name, avatar_url),
            categories(name)
          )
        ''')
        .eq('user_id', userId)
        .eq('listings.status', 'active')
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final listingData = json['listings'] as Map<String, dynamic>;
      final userData = listingData['users'] as Map<String, dynamic>?;
      final categoryData = listingData['categories'] as Map<String, dynamic>?;

      return Listing.fromJson({
        ...listingData,
        'user_name': userData?['name'],
        'user_avatar': userData?['avatar_url'],
        'category_name': categoryData?['name'],
      });
    }).toList();
  }

  // Get favorite count for a listing
  Future<int> getFavoriteCount(String listingId) async {
    final response = await _supabase
        .from('favorites')
        .select('id')
        .eq('listing_id', listingId);

    return (response as List).length;
  }
}
