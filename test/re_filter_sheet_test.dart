// Widget tests for the RE mobile filter bottom sheet (Task P8-T4 of the RE
// parity sprint), `showReFilterSheet` in
// `lib/features/real-estate/presentation/widgets/re_filter_sheet.dart`.
//
// Mirrors the web's `RealEstateFilterDrawer` "Ver N resultados" pattern, but
// WITHOUT a draft/commit split (see that file's doc comment): filter edits
// apply live to `reSearchFiltersProvider`, and the pinned button's count is
// simply `reSearchResultsProvider`'s current length, watched live.
//
// Covers:
//   - Tapping the trigger opens the sheet with the filter controls +
//     "Ver N resultados" button, N == the seeded `reSearchResultsProvider`
//     override's list length.
//   - Toggling a filter chip inside the sheet updates `reSearchFiltersProvider`
//     live (no separate "apply" step).
//   - Tapping "Ver N resultados" closes the sheet.
//
// `reSearchResultsProvider` is overridden directly with a canned list (per
// the task's "cheapest correct source" guidance) so the test doesn't need a
// live Supabase RPC. `listingServiceProvider` is ALSO overridden with a
// no-op fake so `reFacetCountsProvider` (watched by the shared
// `ReFilterControls` for the chip-count suffixes) doesn't touch
// `Supabase.instance` during the test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/real-estate/data/re_models.dart';
import 'package:foxy_ads/features/real-estate/presentation/providers/re_search_provider.dart';
import 'package:foxy_ads/features/real-estate/presentation/widgets/re_filter_sheet.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

class _FakeCountryNotifier extends SelectedCountryNotifier {
  _FakeCountryNotifier(this._initial);
  final Country _initial;
  @override
  Country build() => _initial;
}

/// Never called by these tests (the results count comes from the
/// `reSearchResultsProvider` override), but `reFacetCountsProvider` reads
/// `listingServiceProvider` unconditionally, so a real `ListingService` would
/// otherwise reach for `Supabase.instance` and throw.
class _FakeListingService extends ListingService {
  _FakeListingService()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<ReFacetCounts> reFacetCounts(ReFilters f) async {
    return const ReFacetCounts();
  }
}

Listing _listing(String id) {
  return Listing(
    id: id,
    userId: 'user-1',
    categoryId: 'real-estate',
    countryCode: 'ES',
    title: 'Piso en Madrid $id',
    description: 'desc',
    price: 200000,
    images: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

ProviderContainer _buildContainer(List<Listing> canned) {
  return ProviderContainer(
    overrides: [
      selectedCountryProvider.overrideWith(
        () => _FakeCountryNotifier(_testCountry),
      ),
      listingServiceProvider.overrideWithValue(_FakeListingService()),
      reSearchResultsProvider.overrideWith((ref) async => canned),
    ],
  );
}

Widget _pump(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showReFilterSheet(context),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'opens the sheet with filter controls and the live "Ver N resultados" button',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final canned = [_listing('l-1'), _listing('l-2'), _listing('l-3')];
      final container = _buildContainer(canned);
      addTearDown(container.dispose);

      await tester.pumpWidget(_pump(container));
      await tester.pumpAndSettle();

      expect(find.text('Ver 3 resultados'), findsNothing);

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();

      // The sheet is open: shared filter controls are visible...
      expect(find.text('Tipo de propiedad'), findsOneWidget);
      // ...and the pinned button reflects the seeded results count.
      expect(find.text('Ver 3 resultados'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Limpiar todo'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'toggling a filter chip inside the sheet applies live to reSearchFiltersProvider',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer(const []);
      addTearDown(container.dispose);

      await tester.pumpWidget(_pump(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();

      expect(
        container.read(reSearchFiltersProvider).propertyTypes,
        isEmpty,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Piso'));
      await tester.pumpAndSettle();

      // Applied live — no separate "apply" step, unlike the web's draft.
      expect(
        container.read(reSearchFiltersProvider).propertyTypes,
        ['piso'],
      );
    },
  );

  testWidgets(
    'tapping "Ver N resultados" closes the sheet',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = _buildContainer([_listing('l-1')]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_pump(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Ver 1 resultados'), findsOneWidget);

      await tester.tap(find.text('Ver 1 resultados'));
      await tester.pumpAndSettle();

      expect(find.text('Ver 1 resultados'), findsNothing);
    },
  );
}
