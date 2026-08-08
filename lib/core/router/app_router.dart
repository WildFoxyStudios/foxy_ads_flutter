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
import '../../features/listings/presentation/screens/all_listings_screen.dart';
import '../../features/real-estate/presentation/screens/inmuebles_en_screen.dart';
import '../../features/real-estate/presentation/screens/city_landing_screen.dart';
import '../../features/real-estate/presentation/screens/valuation_screen.dart';
import '../../features/real-estate/data/re_attributes.dart';
import '../../features/real-estate/presentation/providers/re_search_provider.dart';
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

/// Root `Navigator` key, shared with the `GoRouter` below. Exposed as its own
/// provider so widgets mounted OUTSIDE the routed tree — namely `ChatBubble`,
/// which sits in a `Stack` alongside `MaterialApp.router`'s `builder` child
/// rather than inside it — can still obtain a `BuildContext` that has a
/// `Navigator` ancestor (via `navigatorKey.currentContext`) to open a modal
/// bottom sheet. A context taken directly from within `builder`'s `Stack` has
/// no such ancestor: the app's only `Navigator` lives inside the `child`
/// subtree that GoRouter builds, which is a SIBLING of, not an ancestor of,
/// anything else placed in that `Stack`.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>(debugLabel: 'root');
});

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: ref.watch(rootNavigatorKeyProvider),
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
          // Real-estate faceted search — a first-class bottom-nav tab, so it
          // lives inside the shell (keeps the bottom bar). The `:city`
          // drill-down + `/categoria/real_estate*` deep-link aliases stay
          // outside the shell (they're pushed, with a back button).
          GoRoute(
            path: '/inmuebles-en',
            name: 'realEstateSearch',
            builder: (context, state) => const InmueblesEnScreen(),
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
      // Subcategory listings — filters by BOTH category_id and
      // subcategory_id. Registered after the plain `/category/:categoryId`
      // route for clarity (go_router matches by segment count, so there's
      // no shadowing between the two).
      GoRoute(
        path: '/category/:categoryId/:subcategoryId',
        name: 'categorySubcategoryListings',
        builder: (context, state) {
          final categoryId = state.pathParameters['categoryId']!;
          final subcategoryId = state.pathParameters['subcategoryId']!;
          final categoryName = state.uri.queryParameters['name'] ?? 'Categoría';
          return CategoryListingsScreen(
            categoryId: categoryId,
            categoryName: categoryName,
            subcategoryId: subcategoryId,
          );
        },
      ),
      GoRoute(
        path: '/categories',
        name: 'allCategories',
        builder: (context, state) => const AllCategoriesScreen(),
      ),
      // Browse-all listings with a sort dropdown (mirrors the web's
      // /anuncios).
      GoRoute(
        path: AppRoutes.allListings,
        name: 'allListings',
        builder: (context, state) => const AllListingsScreen(),
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

      // City landing — pre-filtered search for a single city
      GoRoute(
        path: '/inmuebles-en/:city',
        name: 'cityLanding',
        builder: (context, state) {
          final city = state.pathParameters['city']!;
          return CityLandingScreen(city: city);
        },
      ),
      // /categoria/real_estate -> /inmuebles-en (web-canonical alias).
      // MUST be declared after `/inmuebles-en/:city` so the static path
      // isn't shadowed by the dynamic `:city` route.
      GoRoute(
        path: '/categoria/real_estate',
        name: 'categoriaRealEstate',
        builder: (context, state) => const InmueblesEnScreen(),
      ),
      // /categoria/real_estate/:subId -> /inmuebles-en with a propertyType
      // pre-selected via the wrapper. Unknown subIds no-op (wrapper renders
      // the unfiltered screen). Same priority note as the route above.
      GoRoute(
        path: '/categoria/real_estate/:subId',
        name: 'categoriaRealEstateSub',
        builder: (context, state) {
          final subId = state.pathParameters['subId']!;
          return _ReAliasWrapper(subId: subId);
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
          retryLabel: l.commonErrorFallbackBackHome,
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
  static const String allListings = '/anuncios';

  // Web-canonical real-estate aliases (Plan 7 T7). Mirror the web's
  // /categoria/real_estate/* paths so shared links from the marketing site
  // land on the right screen in-app.
  static const String categoriaRealEstate = '/categoria/real_estate';
  static String categoriaRealEstateSub(String subId) =>
      '/categoria/real_estate/$subId';

  static String listingDetail(String id) => '/listing/$id';
  static String editListing(String id) => '/edit-listing/$id';
  static String categoryListings(String categoryId, String name) =>
      '/category/$categoryId?name=$name';
  static String categorySubcategoryListings(
    String categoryId,
    String subcategoryId,
    String name,
  ) =>
      '/category/$categoryId/$subcategoryId?name=$name';
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

/// Routes /categoria/real_estate/:subId into [InmueblesEnScreen] with a
/// property-type filter pre-selected. Used only by the Plan 7 web-canonical
/// alias routes; the canonical /inmuebles-en path stays unwrapped so its
/// initial filter state is always defaults.
///
/// Why a wrapper and not a constructor arg on [InmueblesEnScreen]:
///   * The screen holds four `TextEditingController`s in its state; passing
///     a "seed" filter through the constructor would also require seeding
///     the controllers, which is a deeper refactor than this alias warrants.
///   * Toggling the filter via the existing `reSearchFiltersProvider` from
///     a post-frame callback keeps the alias additive — no new constructor
///     signature, no new provider.
///
/// The check is against `RE_PROPERTY_TYPES` (the wire-value list) so an
/// unknown subId (e.g. `/categoria/real_estate/nonsense`) renders the screen
/// in its default unfiltered state rather than throwing or seeding garbage.
class _ReAliasWrapper extends ConsumerStatefulWidget {
  const _ReAliasWrapper({required this.subId});
  final String subId;

  @override
  ConsumerState<_ReAliasWrapper> createState() => _ReAliasWrapperState();
}

class _ReAliasWrapperState extends ConsumerState<_ReAliasWrapper> {
  @override
  void initState() {
    super.initState();
    // Defer the provider mutation until after the first frame so we never
    // mutate state during `build` (Riverpod asserts in profile mode).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!RE_PROPERTY_TYPES.contains(widget.subId)) return;
      ref.read(reSearchFiltersProvider.notifier).toggleString(
            'propertyTypes',
            value: widget.subId,
          );
    });
  }

  @override
  Widget build(BuildContext context) => const InmueblesEnScreen();
}
