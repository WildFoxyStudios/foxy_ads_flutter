// Widget test for the home screen's Plan 11 (F3) additions:
//   1. The hero search bar is a real TextField — submitting a non-empty
//      query navigates to `/search?q=<query>` (the search screen hydrates
//      `?q` and runs the search — see search_screen_empty_state_test.dart).
//   2. A "publish your ad" CTA band renders near the bottom of the home
//      (after recent listings) and tapping its button navigates to
//      `/create-listing`.
//
// Both `categoriesProvider`/`featuredListingsProvider`/`recentListingsProvider`
// (defined in home_screen.dart) are overridden directly with empty-list
// futures so the test never touches Supabase, and `selectedCountryProvider`
// is overridden with a fake Notifier (same pattern as
// all_listings_screen_test.dart) so it never hits SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:foxy_ads/core/models/category_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/features/home/presentation/screens/home_screen.dart';
import 'package:foxy_ads/features/home/presentation/widgets/category_card.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => _testCountry;
}

Widget _buildTestApp({
  required ValueChanged<String> onSearchLocation,
  List<Category>? categories,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          onSearchLocation(state.uri.toString());
          return const Scaffold(body: Text('search-stub'));
        },
      ),
      GoRoute(
        path: '/create-listing',
        builder: (_, _) => const Scaffold(body: Text('create-listing-stub')),
      ),
      GoRoute(
        path: '/select-country',
        builder: (_, _) => const Scaffold(body: Text('select-country-stub')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      categoriesProvider.overrideWith((ref) async => categories ?? <Category>[]),
      featuredListingsProvider.overrideWith((ref) async => <Listing>[]),
      recentListingsProvider.overrideWith((ref) async => <Listing>[]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
    ),
  );
}

void main() {
  testWidgets(
    'hero search: submitting a query navigates to /search?q=<query>',
    (tester) async {
      String? lastSearchLocation;
      await tester.pumpWidget(
        _buildTestApp(
          onSearchLocation: (loc) => lastSearchLocation = loc,
        ),
      );
      await tester.pumpAndSettle();

      // The hero search is a real TextField now (not the old tap-to-navigate
      // stub) — confirm it exists and accepts input.
      final heroField = find.byType(TextField);
      expect(heroField, findsOneWidget);

      await tester.enterText(heroField, 'iphone');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(lastSearchLocation, '/search?q=iphone');
    },
  );

  testWidgets(
    'hero search: empty submit navigates to plain /search',
    (tester) async {
      String? lastSearchLocation;
      await tester.pumpWidget(
        _buildTestApp(
          onSearchLocation: (loc) => lastSearchLocation = loc,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(lastSearchLocation, '/search');
    },
  );

  testWidgets(
    'publish CTA band renders and tapping its button navigates to /create-listing',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      await tester.pumpWidget(
        _buildTestApp(onSearchLocation: (_) {}),
      );
      await tester.pumpAndSettle();

      final ctaButton = find.widgetWithText(ElevatedButton, l10n.homeCtaButton);
      await tester.scrollUntilVisible(
        ctaButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.homeCtaHeading), findsOneWidget);
      expect(find.text(l10n.homeCtaBody), findsOneWidget);
      expect(ctaButton, findsOneWidget);

      // scrollUntilVisible stops as soon as the widget's rect first
      // intersects the viewport, which can leave its *center* (what tap()
      // targets) just past the bottom edge. Nudge it further into view.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();

      await tester.tap(ctaButton);
      await tester.pumpAndSettle();

      expect(find.text('create-listing-stub'), findsOneWidget);
    },
  );

  testWidgets(
    'home category rail hides adult categories (Plan 13 F2)',
    (tester) async {
      final regular = Category(
        id: 'vehicles',
        name: 'Vehicles',
        nameEs: 'Vehículos',
        icon: '🚗',
        color: '#FF6B35',
        sortOrder: 2,
      );
      final adult = Category(
        id: 'contacts',
        name: 'Contacts',
        nameEs: 'Contactos',
        icon: '💋',
        color: '#E91E63',
        sortOrder: 18,
        isAdult: true,
      );

      await tester.pumpWidget(
        _buildTestApp(
          onSearchLocation: (_) {},
          categories: [regular, adult],
        ),
      );
      await tester.pumpAndSettle();

      // The non-adult category renders on the home rail...
      expect(find.text('Vehicles'), findsOneWidget);
      // ...but the adult category (isAdult: true) does not, matching the
      // web home (CategoryGrid.tsx only slices the first 8 non-adult
      // categories). Only one CategoryCard should be built.
      expect(find.text('Contacts'), findsNothing);
      expect(find.byType(CategoryCard), findsOneWidget);
    },
  );
}
