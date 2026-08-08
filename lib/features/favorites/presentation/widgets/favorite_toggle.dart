// Shared favorite-heart binding for the production grids (home,
// all_listings, category_listings). Returns the `(isFavorite,
// onFavorite)` pair that the card expects, or a null callback when the
// user is signed out — in which case the card hides the heart entirely
// (mirroring the web's behavior: the heart is NOT a path to /login).
//
// Eager invalidation: we fire the RPC fire-and-forget AND invalidate the
// favorites providers right away so the heart flips on tap without
// waiting for the round-trip.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/favorite_service.dart';
import '../screens/favorites_screen.dart' show favoritesListProvider;

typedef FavoriteBinding = ({bool isFavorite, VoidCallback? onFavorite});

FavoriteBinding favoriteBinding(WidgetRef ref, String listingId) {
  final auth = ref.watch(authStateProvider);
  final user = auth.value;
  if (user == null) return (isFavorite: false, onFavorite: null);

  final favList = ref.watch(userFavoritesProvider).value ?? <String>[];
  final isFavorite = favList.contains(listingId);

  return (
    isFavorite: isFavorite,
    onFavorite: () {
      // Async fire-and-forget: don't await — the optimistic invalidation
      // flips the heart immediately.
      // ignore: discarded_futures
      ref.read(favoriteServiceProvider).toggleFavorite(user.id, listingId);
      ref.invalidate(userFavoritesProvider);
      ref.invalidate(favoritesListProvider);
    },
  );
}