import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/listings/presentation/screens/listing_detail_screen.dart';
import '../../features/listings/presentation/screens/create_listing_screen.dart';
import '../../features/listings/presentation/screens/category_listings_screen.dart';
import '../../features/listings/presentation/screens/all_categories_screen.dart';
import '../../features/real-estate/presentation/screens/inmuebles_en_screen.dart';
import '../../features/real-estate/presentation/screens/city_landing_screen.dart';
import '../../features/real-estate/presentation/screens/valuation_screen.dart';
import '../../features/developments/presentation/screens/promociones_screen.dart';
import '../../features/developments/presentation/screens/promocion_detail_screen.dart';
import '../../features/developments/presentation/screens/development_form_screen.dart';
import '../../features/agency/presentation/screens/agency_profile_edit_screen.dart';
import '../../features/agency/presentation/screens/agency_profile_screen.dart';
import '../../features/agency/presentation/screens/panel_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/search/presentation/screens/saved_searches_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/my_listings_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/country_selection_screen.dart';
import '../../features/payments/presentation/screens/payment_cancelled_screen.dart';
import '../../features/payments/presentation/screens/payment_success_screen.dart';
import '../../features/payments/presentation/screens/promote_listing_screen.dart';
import '../../features/static/screens/help_screen.dart';
import '../../features/static/screens/contact_screen.dart';
import '../../features/static/screens/privacy_screen.dart';
import '../../features/static/screens/terms_screen.dart';
import '../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/error_view.dart';
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

      // Real-estate faceted search
      GoRoute(
        path: '/inmuebles-en',
        name: 'realEstateSearch',
        builder: (context, state) => const InmueblesEnScreen(),
      ),
      // City landing — pre-filtered search for a single city
      GoRoute(
        path: '/inmuebles-en/:city',
        name: 'cityLanding',
        builder: (context, state) {
          final city = state.pathParameters['city']!;
          return CityLandingScreen(city: city);
        },
      ),
      // Property valuation form
      GoRoute(
        path: '/valorar',
        name: 'valuation',
        builder: (context, state) => const ValuationScreen(),
      ),
      // Developments (obra nueva) index.
      GoRoute(
        path: '/promociones',
        name: 'promociones',
        builder: (context, state) => const PromocionesScreen(),
      ),
      // Development (obra nueva) detail.
      GoRoute(
        path: '/promocion/:id',
        name: 'promocionDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PromocionDetailScreen(developmentId: id);
        },
      ),
      // Agency create/edit form for a development (obra nueva). Auth +
      // verified-agency gate lives inside the screen.
      // MUST be declared before `/promocion-editar/:id` so the static path
      // isn't shadowed by the dynamic `:id` route (same lesson as T4's
      // `/agencia/editar` vs `/agencia/:id`).
      GoRoute(
        path: '/promocion-editar',
        name: 'developmentCreate',
        builder: (context, state) => const DevelopmentFormScreen(),
      ),
      GoRoute(
        path: '/promocion-editar/:id',
        name: 'developmentEdit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DevelopmentFormScreen(developmentId: id);
        },
      ),
      // Edit the caller's own agency profile (auth-gated internally).
      // MUST be declared before `/agencia/:id` so `editar` isn't consumed
      // as an `id` path parameter by the dynamic route.
      GoRoute(
        path: '/agencia/editar',
        name: 'agencyEdit',
        builder: (context, state) => const AgencyProfileEditScreen(),
      ),
      // Public agency profile.
      GoRoute(
        path: '/agencia/:id',
        name: 'agencyProfile',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AgencyProfileScreen(agencyId: id);
        },
      ),
      // Pro Dashboard — auth-gated internally; the verified-agency gate
      // lives inside `PanelScreen` (mirrors the web's `/panel` page).
      GoRoute(
        path: '/panel',
        name: 'panel',
        builder: (context, state) => const PanelScreen(),
      ),

      // Static pages (Sprint 5 Task 6): ported verbatim from the web's
      // /ayuda, /contacto, /privacidad, /terminos. No shadowing concerns —
      // all four are static paths.
      GoRoute(
        path: AppRoutes.ayuda,
        name: 'ayuda',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: AppRoutes.contacto,
        name: 'contacto',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacidad,
        name: 'privacidad',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: AppRoutes.terminos,
        name: 'terminos',
        builder: (context, state) => const TermsScreen(),
      ),

      // Payment return targets (Sprint 7 Task 3). The deep-link resolver
      // (T4) lands here after Stripe Checkout completes/cancels. The session
      // id (`/payment/success`) and original listing id (`/payment/cancelled`)
      // arrive as query parameters.
      GoRoute(
        path: AppRoutes.paymentSuccess,
        name: 'paymentSuccess',
        builder: (context, state) {
          final sessionId = state.uri.queryParameters['session_id'];
          return PaymentSuccessScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: AppRoutes.paymentCancelled,
        name: 'paymentCancelled',
        builder: (context, state) {
          final listingId = state.uri.queryParameters['listing_id'];
          return PaymentCancelledScreen(listingId: listingId);
        },
      ),
      // Email verification gate (T1). Gated between `/payment/*` and the
      // end of the route list so it doesn't shadow any of the static or
      // dynamic routes above.
      GoRoute(
        path: AppRoutes.verifyEmail,
        name: 'verifyEmail',
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return VerifyEmailScreen(redirect: redirect);
        },
      ),
    ],
    errorBuilder: (context, state) {
      final l = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(l.commonErrorFallbackTitle)),
        body: ErrorView(
          title: l.commonErrorFallbackTitle,
          message: l.commonErrorFallbackBody,
          onRetry: () => GoRouter.of(context).go('/'),
        ),
      );
    },
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
  static const String realEstateSearch = '/inmuebles-en';
  static const String promociones = '/promociones';

  static String listingDetail(String id) => '/listing/$id';
  static String editListing(String id) => '/edit-listing/$id';
  static String categoryListings(String categoryId, String name) =>
      '/category/$categoryId?name=$name';
  static String promoteListing(String listingId) => '/promote/$listingId';
  static String cityLanding(String city) => '/inmuebles-en/$city';
  static String valuation() => '/valorar';
  static String promocionDetail(String id) => '/promocion/$id';
  static const String developmentCreate = '/promocion-editar';
  static String developmentEdit(String id) => '/promocion-editar/$id';
  static String agencyProfile(String id) => '/agencia/$id';
  static const String agencyEdit = '/agencia/editar';
  static const String panel = '/panel';

  // Static pages (Sprint 5 Task 6).
  static const String ayuda = '/ayuda';
  static const String contacto = '/contacto';
  static const String privacidad = '/privacidad';
  static const String terminos = '/terminos';

  // Payment return targets (Sprint 7 Task 3).
  static const String paymentSuccess = '/payment/success';
  static const String paymentCancelled = '/payment/cancelled';

  // Email verification gate (T1).
  static const String verifyEmail = '/verify-email';
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
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.listingCreateUnauthorizedEdit)),
          );
        }
        return CreateListingScreen(existing: listing);
      },
    );
  }
}
