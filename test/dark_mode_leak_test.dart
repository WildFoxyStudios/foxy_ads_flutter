// Regression guard for Sprint 9 Task 2 (dark-mode light-only-leak fix).
//
// Three widgets previously hardcoded `AppColors.surface` (a fixed
// `0xFFFFFFFF`) on backgrounds that should follow the active theme:
//   - `development_form_screen.dart`  (3 AppBar surfaces, in 3 scaffolds)
//   - `create_listing_screen.dart`    (1 add-image tile Container)
//   - `saved_searches_screen.dart`    (1 list-item Material card)
//
// The fix introduces `surfaceFor(BuildContext)` which returns
// `Theme.of(context).colorScheme.surface`. In dark mode that's dark, in
// light mode it's the M3 default (off-white). This test asserts:
//
//   * In ThemeMode.dark, none of the swapped surfaces equals
//     `AppColors.surface` (`0xFFFFFFFF`). If a future change reverts
//     any of the three widgets to use `AppColors.surface` directly, the
//     dark-mode pump surfaces the leak and this test FAILS.
//   * In ThemeMode.light, the swapped surfaces still come from the
//     theme (i.e. resolve to something other than a fixed dark color),
//     confirming the helper is wired through.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient, User;

import 'package:foxy_ads/core/models/category_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/models/saved_search_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/core/services/saved_searches_service.dart';
import 'package:foxy_ads/core/theme/app_colors.dart';
import 'package:foxy_ads/features/developments/presentation/screens/development_form_screen.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/features/listings/presentation/screens/create_listing_screen.dart';
import 'package:foxy_ads/features/listings/presentation/screens/listing_detail_screen.dart';
import 'package:foxy_ads/features/search/presentation/providers/search_filters_provider.dart';
import 'package:foxy_ads/features/search/presentation/screens/saved_searches_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test scaffolding
// ---------------------------------------------------------------------------

/// Hardcoded white constant from `AppColors.surface`. We import the constant
/// but never use it in the production code — this test pins the value so a
/// regression that swaps back to `AppColors.surface` is caught.
final Color _hardcodedWhite = AppColors.surface;

/// `SavedSearchesService` test double. Returns the configured list from
/// `list()`; the rest are no-ops so an unexpected call doesn't fail loudly.
class FakeSavedSearchesService extends SavedSearchesService {
  FakeSavedSearchesService(this._items)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final List<SavedSearch> _items;

  @override
  Future<List<SavedSearch>> list() async => _items;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> touchSeen(String id) async {}
}

List<SavedSearch> _savedSearchesFixture() {
  return [
    SavedSearch(
      id: 'ss-1',
      userId: 'u-1',
      categoryId: 'vehicles',
      label: 'Coches Madrid',
      filters: SearchFilters(query: 'coche'),
      rawQuery: const {'query': 'coche'},
      countryCode: 'ES',
      createdAt: DateTime(2026, 1, 1),
    ),
    SavedSearch(
      id: 'ss-2',
      userId: 'u-1',
      categoryId: null,
      label: null,
      filters: SearchFilters(),
      rawQuery: const {},
      countryCode: 'ES',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];
}

/// Signed-in `User` fixture used by the create_listing dark-mode test so the
/// screen renders the form (which contains the swapped add-image tile)
/// instead of the `_NotSignedInScaffold` branch.
User _signedInUser() {
  return User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
}

/// Overrides `SelectedCountryNotifier.build()` so no `SharedPreferences`
/// platform channel is touched during the test.
class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

/// `Listing` fixture for the Sprint 12 Task 2 (dark-mode surface leak sweep)
/// tests below. `userId` is deliberately NOT a UUID so `ListingDetailScreen`
/// skips its "Ver agencia" branch (which needs `agencyProfileProvider`) and
/// the widget builds with only `listingDetailProvider` + `authStateProvider`
/// overridden. `categoryName`/`city` are set so the two `Chip`s that were
/// swapped from `AppColors.surface` to `surfaceFor(context)` actually render.
Listing _listingFixture() {
  return Listing(
    id: 'l-1',
    userId: 'seller-1',
    categoryId: 'vehicles',
    countryCode: 'ES',
    title: 'Coche en venta',
    description: 'Un coche muy bueno.',
    price: 12000,
    images: const [],
    city: 'Madrid',
    categoryName: 'Vehículos',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap({
  required Widget home,
  required ThemeMode themeMode,
}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: themeMode,
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ----- saved_searches_screen.dart ----------------------------------------

  testWidgets(
    'saved_searches_screen list-item Material does not use hardcoded white in dark',
    (tester) async {
      final fake = FakeSavedSearchesService(_savedSearchesFixture());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedSearchesServiceProvider.overrideWithValue(fake),
          ],
          child: _wrap(
            themeMode: ThemeMode.dark,
            home: const SavedSearchesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The Material wrapping each list item has `color: surfaceFor(context)`.
      // Filter to opaque-color Materials to exclude IconButton's transparent
      // splash wrappers and the AppBar's null-color Material.
      final listItemMaterials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) =>
              m.color != null && m.color!.a >= 1.0)
          .toList();
      expect(
        listItemMaterials,
        isNotEmpty,
        reason:
            'Expected at least one opaque-color Material (the list-item '
            'card) on the saved-searches screen.',
      );
      for (final m in listItemMaterials) {
        expect(
          m.color,
          isNot(equals(_hardcodedWhite)),
          reason:
              'saved_searches_screen list-item Material is still using the '
              'hardcoded AppColors.surface ($_hardcodedWhite). Switch to '
              'surfaceFor(context) so it follows the active theme.',
        );
      }
    },
  );

  testWidgets(
    'saved_searches_screen list-item Material follows the light theme too',
    (tester) async {
      final fake = FakeSavedSearchesService(_savedSearchesFixture());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedSearchesServiceProvider.overrideWithValue(fake),
          ],
          child: _wrap(
            themeMode: ThemeMode.light,
            home: const SavedSearchesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listItemMaterials = tester
          .widgetList<Material>(find.byType(Material))
          .where((m) =>
              m.color != null && m.color!.a >= 1.0)
          .toList();
      expect(listItemMaterials, isNotEmpty);
      for (final m in listItemMaterials) {
        expect(
          m.color,
          isNot(equals(_hardcodedWhite)),
          reason:
              'saved_searches_screen list-item Material is still using the '
              'hardcoded AppColors.surface ($_hardcodedWhite).',
        );
      }
    },
  );

  // ----- create_listing_screen.dart ----------------------------------------
  //
  // The single surface swapped in this widget is the add-image tile
  // Container at line 432 (`color: surfaceFor(context)`). That tile only
  // renders in the signed-in branch, so the test overrides
  // `authStateProvider` with a logged-in user (and stubs the categories +
  // selected-country providers so the form builds without a real backend).
  // The test then locates the tile by its icon, reads the resolved
  // `Container`'s `BoxDecoration.color`, and asserts it equals
  // `Theme.of(context).colorScheme.surface` in BOTH light and dark modes.
  //
  // If a future change reverts the Container to `color: AppColors.surface`
  // (the fixed 0xFFFFFFFF), the dark-mode assertion fails because the
  // resolved color would not match the dark color scheme surface. The
  // light-mode assertion additionally guards against the helper being
  // removed entirely (so the constant leaks back in).

  /// Pumps `CreateListingScreen` in the signed-in branch with the minimum
  /// set of provider overrides, then returns the [WidgetTester] and the
  /// `Container` carrying the add-image tile decoration.
  Future<({Container container, BuildContext context})> pumpSignedIn(
    WidgetTester tester, {
    required ThemeMode themeMode,
  }) async {
    // The form is a long ListView (photos, category, title, description,
    // price, contact fields, submit button). At the default 800x600 test
    // surface the add-image tile sits well above the fold so this is not
    // strictly needed, but we match the form-mode test's surface size for
    // consistency in case the layout shifts.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_signedInUser()),
          ),
          createListingCategoriesProvider.overrideWith(
            (ref) async => const <Category>[],
          ),
          selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
        ],
        child: _wrap(
          themeMode: themeMode,
          home: const CreateListingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The add-image tile is the only Container in the form that has an
    // Icon(Icons.add_a_photo) child. Locate it via that icon (stable
    // across refactors) and walk up to the enclosing Container.
    final iconFinder = find.byIcon(Icons.add_a_photo);
    expect(
      iconFinder,
      findsOneWidget,
      reason:
          'Expected the add-a-photo icon to be present in the signed-in '
          'create_listing form (the tile Container is its parent).',
    );
    // Use a context INSIDE the subtree where `surfaceFor(context)` was
    // evaluated (i.e. the Container's own element). `Theme.of` walks up
    // from there and resolves to the active theme honoring `themeMode`
    // — `MaterialApp.theme` alone would yield the light scheme even when
    // the app is in dark mode.
    final ctx = tester.element(
      find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
    );
    final tileContainer = tester.widget<Container>(
      find.ancestor(of: iconFinder, matching: find.byType(Container)).first,
    );

    return (container: tileContainer, context: ctx);
  }

  testWidgets(
    'create_listing add-image tile Container follows the active theme in dark',
    (tester) async {
      final result = await pumpSignedIn(tester, themeMode: ThemeMode.dark);
      final deco = result.container.decoration;
      expect(
        deco,
        isA<BoxDecoration>(),
        reason:
            'Expected the add-image tile to have a BoxDecoration (it sets '
            'color/border/borderRadius in source).',
      );
      final bg = (deco as BoxDecoration).color;
      expect(
        bg,
        isNotNull,
        reason: 'The add-image tile BoxDecoration must declare a color.',
      );
      // 1. The color must NOT be the hardcoded `AppColors.surface`
      //    constant — that's the regression we are guarding against.
      expect(
        bg,
        isNot(equals(_hardcodedWhite)),
        reason:
            'create_listing add-image tile leaked AppColors.surface '
            '($_hardcodedWhite) into dark mode. Switch to surfaceFor(context) '
            'so it follows the active theme.',
      );
      // 2. The color must equal the resolved theme surface — this is
      //    what `surfaceFor(context)` returns. If the helper is wired
      //    through, this assertion holds in both light and dark.
      final expectedSurface =
          Theme.of(result.context).colorScheme.surface;
      expect(
        bg,
        equals(expectedSurface),
        reason:
            'create_listing add-image tile color ($bg) should equal the '
            'resolved theme surface ($expectedSurface) in dark mode.',
      );
      // Sanity: in dark mode the surface must be dark — if a future
      // framework upgrade flips the default, this assertion catches it.
      expect(
        Theme.of(result.context).brightness,
        Brightness.dark,
        reason:
            'Test sanity check: themeMode.dark should resolve to a dark '
            'brightness.',
      );
    },
  );

  testWidgets(
    'create_listing add-image tile Container follows the active theme in light',
    (tester) async {
      final result = await pumpSignedIn(tester, themeMode: ThemeMode.light);
      final deco = result.container.decoration;
      expect(deco, isA<BoxDecoration>());
      final bg = (deco as BoxDecoration).color;
      expect(bg, isNotNull);
      expect(
        bg,
        isNot(equals(_hardcodedWhite)),
        reason:
            'create_listing add-image tile is still using the hardcoded '
            'AppColors.surface ($_hardcodedWhite) in light mode. Switch to '
            'surfaceFor(context) so it follows the active theme.',
      );
      final expectedSurface =
          Theme.of(result.context).colorScheme.surface;
      expect(
        bg,
        equals(expectedSurface),
        reason:
            'create_listing add-image tile color ($bg) should equal the '
            'resolved theme surface ($expectedSurface) in light mode.',
      );
      expect(Theme.of(result.context).brightness, Brightness.light);
    },
  );

  // ----- development_form_screen.dart --------------------------------------

  testWidgets(
    'development_form_screen signed-out AppBar does not use hardcoded white in dark',
    (tester) async {
      // _NotSignedInScaffold is the simplest entry point — auth defaults
      // to null so the screen takes the signed-out branch on the very
      // first build.
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            themeMode: ThemeMode.dark,
            home: const DevelopmentFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The signed-out scaffold renders an AppBar whose backgroundColor
      // is `surfaceFor(context)`. Find it and check the value.
      final appBars = tester.widgetList<AppBar>(find.byType(AppBar));
      expect(appBars, isNotEmpty);
      for (final a in appBars) {
        final color = a.backgroundColor;
        if (color == null) continue;
        expect(
          color,
          isNot(equals(_hardcodedWhite)),
          reason:
              'development_form_screen AppBar is still using the hardcoded '
              'AppColors.surface ($_hardcodedWhite). Switch to '
              'surfaceFor(context) so it follows the active theme.',
        );
      }
    },
  );

  testWidgets(
    'development_form_screen signed-out AppBar follows the light theme too',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            themeMode: ThemeMode.light,
            home: const DevelopmentFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appBars = tester.widgetList<AppBar>(find.byType(AppBar));
      expect(appBars, isNotEmpty);
      for (final a in appBars) {
        final color = a.backgroundColor;
        if (color == null) continue;
        // In light mode the scheme surface is `Color(0xFEF7FF)` — different
        // from `AppColors.surface` (`0xFFFFFFFF`). The helper still goes
        // through `Theme.of(context).colorScheme.surface`, so the
        // resolution is scheme-driven in both modes. We don't pin a
        // specific value (M3 default shifts between SDK versions) — we
        // just guard against the exact constant slipping back in.
        expect(color, isNot(equals(_hardcodedWhite)));
      }
    },
  );

  // ----- listing_card.dart (Sprint 12 Task 2) -------------------------------
  //
  // `ListingCard` is the card widget used in `home_screen`'s recent-listings
  // grid and `search_screen`'s results grid. Its outer `Container` decoration
  // used to hardcode `color: Colors.white`; it now uses `surfaceFor(context)`.

  testWidgets(
    'listing_card outer Container does not use hardcoded white in dark',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: ListingCard(listing: _listingFixture(), onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(find.byType(Container).first);
      final deco = container.decoration;
      expect(deco, isA<BoxDecoration>());
      final bg = (deco as BoxDecoration).color;
      expect(
        bg,
        isNot(equals(_hardcodedWhite)),
        reason:
            'listing_card outer Container leaked AppColors.surface/Colors.white '
            '($_hardcodedWhite) into dark mode. Switch to surfaceFor(context) '
            'so it follows the active theme.',
      );
    },
  );

  // ----- listing_detail_screen.dart (Sprint 12 Task 2) ----------------------
  //
  // Two swapped surfaces: the category/city `Chip`s (`backgroundColor:
  // AppColors.surface` → `surfaceFor(context)`) and the `bottomNavigationBar`
  // Container (`color: Colors.white` → `surfaceFor(context)`). Both sit
  // directly on the scaffold and should follow the active theme; the
  // surrounding white icon-circle buttons and gradient badges are
  // deliberately untouched (foreground chrome atop the photo header/gradient)
  // and are NOT asserted here.

  testWidgets(
    'listing_detail_screen chips and bottom bar do not use hardcoded white in dark',
    (tester) async {
      final listing = _listingFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            listingDetailProvider(
              listing.id,
            ).overrideWith((ref) async => listing),
            authStateProvider.overrideWith(
              (ref) => Stream<User?>.value(null),
            ),
          ],
          child: _wrap(
            themeMode: ThemeMode.dark,
            home: ListingDetailScreen(listingId: listing.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chips = tester.widgetList<Chip>(find.byType(Chip));
      expect(
        chips,
        isNotEmpty,
        reason:
            'Expected the category + city Chips to render (fixture sets '
            'both categoryName and city).',
      );
      for (final chip in chips) {
        expect(
          chip.backgroundColor,
          isNot(equals(_hardcodedWhite)),
          reason:
              'listing_detail_screen Chip is still using the hardcoded '
              'AppColors.surface ($_hardcodedWhite). Switch to '
              'surfaceFor(context) so it follows the active theme.',
        );
      }

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final bottomBar = scaffold.bottomNavigationBar;
      expect(
        bottomBar,
        isA<Container>(),
        reason: 'Expected the listing_detail_screen bottomNavigationBar to '
            'be a Container (it sets color/boxShadow in source).',
      );
      final bottomDeco = (bottomBar as Container).decoration as BoxDecoration;
      expect(
        bottomDeco.color,
        isNot(equals(_hardcodedWhite)),
        reason:
            'listing_detail_screen bottomNavigationBar Container leaked '
            'Colors.white ($_hardcodedWhite) into dark mode. Switch to '
            'surfaceFor(context) so it follows the active theme.',
      );
    },
  );
}