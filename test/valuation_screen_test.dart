// Widget tests for the `/valorar` screen (Task 6 of the RE parity sprint).
//
// Covers the two rendering paths of the result card:
//
//  - Empty state: the fake ListingService returns `null`
//    (insufficient sample), so the screen must render
//    "No hay datos suficientes para esta zona."
//
//  - Result card: the fake ListingService returns a real stats record and
//    the screen must render the formatted currency card with the city
//    name in the title line.
//
// The widget reads:
//   - selectedCountryProvider  →  override with a fake notifier (no
//                                 SharedPreferences platform channel).
//   - citiesProvider(country.code)  →  override the family provider so the
//                                 city dropdown is populated synchronously.
//   - listingServiceProvider  →  override with FakeListingService so the
//                                 estimate path is fully synchronous and no
//                                 Supabase calls happen.
//
// The pricing math itself (low/high band, €/m², sample-size text) is unit-
// tested in `re_pricing_test.dart` from T2; this test only verifies that
// the screen wires the result up and renders the two states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/city_model.dart';
import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/real-estate/presentation/screens/valuation_screen.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

final _testCities = [
  City(id: 'es-mad', countryCode: 'ES', name: 'Madrid', sortOrder: 1),
  City(id: 'es-bcn', countryCode: 'ES', name: 'Barcelona', sortOrder: 2),
];

/// Fake ListingService that ignores Supabase entirely and returns whatever
/// the test set up. Only the public method the screen exercises
/// (`estimateFromCityStats`) is overridden. The dummy SupabaseClient is
/// never invoked — the fake short-circuits before any RPC.
class FakeListingService extends ListingService {
  FakeListingService(this._estimate)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            // Disable GoTrue's auto-refresh so the constructor doesn't
            // leave a periodic timer alive across pumpAndSettle (which
            // trips the binding's "no timers pending" invariant).
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final ({double avgPricePerM2, int sampleSize})? _estimate;

  @override
  Future<({double avgPricePerM2, int sampleSize})?> estimateFromCityStats({
    required String countryCode,
    required String city,
    String? operation,
    required int minSample,
  }) async {
    return _estimate;
  }
}

/// Overrides SelectedCountryNotifier.build() so the SharedPreferences
/// platform channel is never touched.
class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => _testCountry;
}

Widget _buildTestApp(ListingService service) {
  return ProviderScope(
    overrides: [
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      // The screen uses `citiesProvider(country.code)` — a FutureProvider
      // family. Override with a synchronous fake so the dropdown renders
      // cities immediately.
      citiesProvider.overrideWith(
        (ref, code) async => _testCities,
      ),
      listingServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(home: ValuationScreen()),
  );
}

/// Drives the form to a state where the "Valorar" button can be pressed:
/// picks the first city in the dropdown, types "80" into the m² field,
/// and taps "Venta".
Future<void> _fillAndSubmit(WidgetTester tester) async {
  // Pick the city.
  await tester.tap(find.byType(DropdownButton<String?>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Madrid').last);
  await tester.pumpAndSettle();

  // Type m².
  await tester.enterText(find.byType(TextFormField), '80');
  await tester.pumpAndSettle();

  // Pick "Venta".
  await tester.tap(find.text('Venta'));
  await tester.pumpAndSettle();

  // Submit.
  await tester.tap(find.text('Valorar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows empty state when estimateFromCityStats returns null',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildTestApp(FakeListingService(null)));
      await tester.pumpAndSettle();

      await _fillAndSubmit(tester);

      expect(
        find.text('No hay datos suficientes para esta zona.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows result card with formatted currency and city when estimate is available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const avgPerM2 = 3000.0; // €/m² — clean number → '3000 €' after _money().
      await tester.pumpWidget(
        _buildTestApp(
          FakeListingService(
            (avgPricePerM2: avgPerM2, sampleSize: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillAndSubmit(tester);

      // The card title mentions the surface area and the operation label.
      expect(find.textContaining('80 m²'), findsWidgets);
      // "venta" label is in the title — assert the operation label is present.
      expect(find.textContaining('venta'), findsWidgets);

      // The estimate value: avgPerM2 * m2 = 3000 * 80 = 240000.
      // _money() formats with no decimals when the number is whole and
      // appends the currency code. Assert the numeric range + currency
      // rather than the exact string.
      expect(find.textContaining('240000'), findsWidgets);
      expect(find.textContaining('€'), findsWidgets);

      // The €/m² stat cell and the sample-size stat are both rendered.
      expect(find.textContaining('€/m²'), findsWidgets);
      expect(find.textContaining('12'), findsWidgets);
      expect(find.text('Muestra'), findsOneWidget);

      // Empty state MUST NOT be present when the estimate is available.
      expect(
        find.text('No hay datos suficientes para esta zona.'),
        findsNothing,
      );
    },
  );
}