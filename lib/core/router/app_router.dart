import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/listings/presentation/screens/category_listings_screen.dart';
import '../../features/listings/presentation/screens/all_categories_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/screens/saved_searches_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/my_listings_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/country_selection_screen.dart';
import '../../features/payments/presentation/screens/promote_listing_screen.dart';
import '../services/auth_service.dart';
import '../widgets/main_navigation_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main App Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainNavigationShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Listing Routes
      GoRoute(
        path: '/listing/:id',
        name: 'listingDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ListingDetailScreen(listingId: id);
        },
      ),
      GoRoute(
        path: '/create-listing',
        name: 'createListing',
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: '/edit-listing/:id',
        name: 'editListing',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _EditListingRoute(listingId: id);
        },
      ),
      GoRoute(
        path: '/category/:categoryId',
        name: 'categoryListings',
        builder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          final categoryName = state.uri.queryParameters['name'] ?? 'Categoría';
          return CategoryListingsScreen(
            categoryId: categoryId,
            categoryName: categoryName,
          );
        },
      ),
      GoRoute(
        path: '/categories',
        name: 'allCategories',
        builder: (context, state) => const AllCategoriesScreen(),
      ),

      // Profile Routes
      GoRoute(
        path: '/my-listings',
        name: 'myListings',
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'editProfile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/saved-searches',
        name: 'savedSearches',
        builder: (context, state) => const SavedSearchesScreen(),
      ),

      // Settings Routes
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/select-country',
        name: 'selectCountry',
        builder: (context, state) => const CountrySelectionScreen(),
      ),

      // Payment Routes
      GoRoute(
        path: '/promote/:listingId',
        name: 'promoteListing',
        builder: (context, state) {
          final listingId = state.pathParameters['listingId']!;
          return PromoteListingScreen(listingId: listingId);
        },
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Error: ${state.error}'))),
  );
});

class AppRoutes {
  static const String splash = '/splash';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String profile = '/profile';
  static const String createListing = '/create-listing';
  static const String myListings = '/my-listings';
  static const String editProfile = '/edit-profile';
  static const String savedSearches = '/saved-searches';
  static const String settings = '/settings';
  static const String selectCountry = '/select-country';

  static String listingDetail(String id) => '/listing/$id';
  static String editListing(String id) => '/edit-listing/$id';
  static String categoryListings(String categoryId, String name) =>
      '/category/$categoryId?name=$name';
  static String promoteListing(String listingId) => '/promote/$listingId';
}

/// Loads the listing by [listingId] and, if the current user is its owner,
/// hands it to [CreateListingScreen] in edit mode. Defense-in-depth only —
/// RLS enforces ownership server-side regardless of this check.
class _EditListingRoute extends ConsumerWidget {
  final String listingId;

  const _EditListingRoute({required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailProvider(listingId));

    return listingAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (listing) {
        final currentUserId = ref.watch(authStateProvider).value?.id;
        if (listing == null || listing.userId != currentUserId) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('No autorizado para editar')),
          );
        }
        return CreateListingScreen(existing: listing);
      },
    );
  }
}
