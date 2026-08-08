// Subcategory dropdown + state/province field in CreateListingScreen
// (Sprint 9 Task B4).
//
// Covers:
// - A category with subcategories (from `categoriesWithSubcategoriesProvider`)
//   shows the subcategory dropdown once selected, with the right options.
// - Switching to a category with NO subcategories hides the dropdown again
//   AND resets `_subcategoryId` (verified by the dropdown disappearing —
//   if the id had survived, the widget would either still render the old
//   category's items or crash on an unmatched `value`).
// - The state/province field renders and round-trips typed text through its
//   controller (the same controller `_submitListing` reads via
//   `_stateController.text` when building the insert/update payload — see
//   create_listing_screen.dart).
// - Edit mode pre-selects the listing's existing subcategoryId and prefills
//   the state field from `listing.state`.
//
// Providers touched during build (createListingCategoriesProvider,
// categoriesWithSubcategoriesProvider, authStateProvider,
// selectedCountryProvider) are all overridden so the widget builds
// synchronously with no network / platform-channel calls, mirroring
// listing_form_mode_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:foxy_ads/core/models/category_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/listings/presentation/screens/create_listing_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _fakeUser = User(
  id: 'test-user-id',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

// Flat list backing the category dropdown itself (createListingCategoriesProvider
// / ListingService.getCategories()). 'vehicles' HAS subcategories (per the
// richer list below); 'electronics' has none.
final _fakeCategories = [
  Category(
    id: 'vehicles',
    name: 'Vehicles',
    nameEs: 'Vehículos',
    icon: '🚗',
    color: '#FF6B35',
    sortOrder: 1,
  ),
  Category(
    id: 'electronics',
    name: 'Electronics',
    nameEs: 'Electrónica',
    icon: '📱',
    color: '#4ECDC4',
    sortOrder: 2,
  ),
];

// Richer list backing categoriesWithSubcategoriesProvider: only 'vehicles'
// carries subcategories, matching the audit's "no subcategories -> no
// dropdown" requirement for 'electronics'.
final _fakeCategoriesWithSubs = [
  Category(
    id: 'vehicles',
    name: 'Vehicles',
    nameEs: 'Vehículos',
    icon: '🚗',
    color: '#FF6B35',
    sortOrder: 1,
    subcategories: [
      Category(
        id: 'veh_cars',
        name: 'Cars',
        nameEs: 'Coches',
        icon: '',
        color: '',
        sortOrder: 1,
        parentId: 'vehicles',
      ),
      Category(
        id: 'veh_motorcycles',
        name: 'Motorcycles',
        nameEs: 'Motos',
        icon: '',
        color: '',
        sortOrder: 2,
        parentId: 'vehicles',
      ),
    ],
  ),
  Category(
    id: 'electronics',
    name: 'Electronics',
    nameEs: 'Electrónica',
    icon: '📱',
    color: '#4ECDC4',
    sortOrder: 2,
  ),
];

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

final _fakeListingWithSubcategory = Listing(
  id: 'listing-1',
  userId: 'test-user-id',
  categoryId: 'vehicles',
  subcategoryId: 'veh_motorcycles',
  countryCode: 'ES',
  title: 'Moto de prueba en venta',
  description: 'Una descripción de prueba con más de veinte caracteres.',
  price: 1500,
  currency: 'EUR',
  state: 'Madrid',
  // Empty on purpose — see listing_form_mode_test.dart for why.
  images: const [],
  isNegotiable: false,
  createdAt: DateTime(2026, 1, 1),
);

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_fakeUser)),
      createListingCategoriesProvider.overrideWith(
        (ref) => Future.value(_fakeCategories),
      ),
      categoriesWithSubcategoriesProvider.overrideWith(
        (ref) => Future.value(_fakeCategoriesWithSubs),
      ),
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  // Tall surface so the full ListView (photos, category, subcategory,
  // title, ..., city, state, contact fields) lays out without scrolling —
  // matches listing_form_mode_test.dart's rationale.

  testWidgets(
    'selecting a category with subcategories shows the subcategory dropdown '
    'with its options; switching to a category with none hides it again',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(const CreateListingScreen()));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      // Before any category is picked, the subcategory dropdown must not
      // render at all.
      expect(find.text(l10n.listingCreateSubcategoryLabel), findsNothing);

      // Pick 'Vehículos' (has subcategories) from the category dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<Category>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehículos').last);
      await tester.pumpAndSettle();

      // Subcategory dropdown now appears with the right options.
      expect(find.text(l10n.listingCreateSubcategoryLabel), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Coches').last, findsOneWidget);
      expect(find.text('Motos').last, findsOneWidget);

      // Select a subcategory.
      await tester.tap(find.text('Motos').last);
      await tester.pumpAndSettle();
      expect(find.text('Motos'), findsOneWidget);

      // Switch to 'Electrónica' (no subcategories) — the dropdown (and the
      // previously-selected subcategory) must disappear.
      await tester.tap(find.byType(DropdownButtonFormField<Category>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electrónica').last);
      await tester.pumpAndSettle();

      expect(find.text(l10n.listingCreateSubcategoryLabel), findsNothing);
      expect(find.text('Motos'), findsNothing);
    },
  );

  testWidgets(
    'the state/province field renders and round-trips typed text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(const CreateListingScreen()));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      final fieldFinder = find.ancestor(
        of: find.text(l10n.listingCreateStateLabel),
        matching: find.byType(TextFormField),
      );
      expect(fieldFinder, findsOneWidget);

      await tester.enterText(fieldFinder, 'Andalucía');
      await tester.pumpAndSettle();

      expect(find.text('Andalucía'), findsOneWidget);
    },
  );

  testWidgets(
    'edit mode pre-selects the subcategory and prefills the state field',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestApp(
          CreateListingScreen(existing: _fakeListingWithSubcategory),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('es'));

      // Category prefill (existing behavior) fires the subcategory dropdown
      // into view; its pre-selected value is the listing's subcategory.
      expect(find.text(l10n.listingCreateSubcategoryLabel), findsOneWidget);
      expect(find.text('Motos'), findsOneWidget);

      // The state field is prefilled from `listing.state`.
      expect(find.text('Madrid'), findsOneWidget);
    },
  );
}
