// Pins CreateListingScreen's create-vs-edit form mode (Task 4):
// - Create mode (`const CreateListingScreen()`): AppBar + submit button show
//   the create copy.
// - Edit mode (`CreateListingScreen(existing: fakeListing)`): AppBar shows
//   the localized "Editar anuncio", the submit button shows the localized
//   "Guardar cambios", and the title field is prefilled with the listing's
//   title.
//
// The screen reads several providers during build/initState
// (createListingCategoriesProvider, authStateProvider, selectedCountryProvider,
// which in turn touches supabaseClientProvider and SharedPreferences). All are
// overridden here so the widget builds synchronously without any network or
// platform-channel calls.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:foxy_ads/core/models/category_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/listings/presentation/screens/create_listing_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

// A logged-in fake user so the screen renders the form instead of the
// "Inicia sesión para publicar" gate.
final _fakeUser = User(
  id: 'test-user-id',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

final _fakeCategories = [
  Category(
    id: 'vehicles',
    name: 'Vehicles',
    nameEs: 'Vehículos',
    icon: '🚗',
    color: '#FF6B35',
    sortOrder: 1,
  ),
];

// Overrides SelectedCountryNotifier.build() so no SharedPreferences platform
// channel is touched during the test.
class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

final _fakeListing = Listing(
  id: 'listing-1',
  userId: 'test-user-id',
  categoryId: 'vehicles',
  countryCode: 'ES',
  title: 'Piso de prueba',
  description: 'Una descripción de prueba con más de veinte caracteres.',
  price: 1500,
  currency: 'EUR',
  // Empty on purpose: a network image URL here would trigger a real
  // NetworkImageLoadException in the test environment (Image.network has no
  // error builder in the screen), which destabilizes pumpAndSettle. The
  // form-mode assertions below don't depend on image rendering.
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
  // The form is a long ListView (photos, category, title, description,
  // price, contact fields, submit button). At the default 800x600 test
  // surface the submit button sits below the fold and a plain ListView
  // (SliverChildListDelegate) only mounts widgets that intersect the
  // viewport, so `find.text` can't see it without scrolling. Use a tall
  // surface instead so the whole form is laid out and visible.

  testWidgets(
    'create mode shows the create title and submit label',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(const CreateListingScreen()));
      await tester.pumpAndSettle();

      // Resolve the locale AppLocalizations that's active in the test app
      // (default = 'es', matching the app's first-run locale).
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(find.text(l10n.listingCreateTitle), findsWidgets);
      expect(find.text(l10n.listingEditTitle), findsNothing);
      expect(find.text(l10n.listingCreateSaveChangesButton), findsNothing);
    },
  );

  testWidgets(
    'edit mode shows the edit title, save label, and prefilled title field',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestApp(CreateListingScreen(existing: _fakeListing)),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      expect(find.text(l10n.listingEditTitle), findsOneWidget);
      expect(find.text(l10n.listingCreateSaveChangesButton), findsOneWidget);
      expect(find.text(l10n.listingCreateTitle), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'Piso de prueba'),
        findsOneWidget,
      );
    },
  );
}
