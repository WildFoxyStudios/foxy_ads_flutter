// Widget tests for the `/promociones` index screen (Task 3 of the
// developments/promociones sprint).
//
// Covers the two rendering paths:
//  - Empty state: FakeDevelopmentsService returns `[]` -> empty-state text
//    is rendered.
//  - Data state: FakeDevelopmentsService returns 2 DevelopmentCardData items
//    -> exactly 2 DevelopmentCard widgets are rendered.
//
// Follows the same fake-supabase-with-autoRefreshToken:false pattern that
// Sprint 2's valuation_screen_test.dart used to construct the base service,
// and overrides selectedCountryProvider so no SharedPreferences platform
// channel is touched.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/features/developments/data/development_model.dart';
import 'package:foxy_ads/features/developments/data/developments_service.dart';
import 'package:foxy_ads/features/developments/presentation/screens/promociones_screen.dart';
import 'package:foxy_ads/features/developments/presentation/widgets/development_card.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

/// Fake DevelopmentsService that ignores Supabase entirely and returns
/// whatever the test set up. Only fetchDevelopmentsForCountry is
/// overridden; the dummy SupabaseClient is never invoked.
class FakeDevelopmentsService extends DevelopmentsService {
  FakeDevelopmentsService(this._items)
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

  final List<DevelopmentCardData> _items;

  @override
  Future<List<DevelopmentCardData>> fetchDevelopmentsForCountry(
    String countryCode, {
    String? city,
    int limit = 60,
  }) async {
    return _items;
  }
}

/// Overrides SelectedCountryNotifier.build() so the SharedPreferences
/// platform channel is never touched.
class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => _testCountry;
}

Development _development(String id, String name) {
  return Development(
    id: id,
    agencyUserId: 'agency-1',
    name: name,
    countryCode: 'ES',
    city: 'Madrid',
    status: 'published',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp(List<DevelopmentCardData> items) {
  return ProviderScope(
    overrides: [
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      developmentsServiceProvider.overrideWithValue(
        FakeDevelopmentsService(items),
      ),
    ],
    child: const MaterialApp(home: PromocionesScreen()),
  );
}

void main() {
  testWidgets('shows empty state when there are no developments', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(const []));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Aún no hay promociones'),
      findsOneWidget,
    );
    expect(find.byType(DevelopmentCard), findsNothing);
  });

  testWidgets('shows 2 DevelopmentCards when 2 developments are returned', (
    tester,
  ) async {
    final items = [
      DevelopmentCardData(
        development: _development('dev-1', 'Residencial Sol'),
        priceFrom: 150000,
        currency: 'EUR',
        unitCount: 12,
      ),
      DevelopmentCardData(
        development: _development('dev-2', 'Residencial Luna'),
        unitCount: 0,
      ),
    ];

    await tester.pumpWidget(_buildTestApp(items));
    await tester.pumpAndSettle();

    expect(find.byType(DevelopmentCard), findsNWidgets(2));
    expect(find.text('Residencial Sol'), findsOneWidget);
    expect(find.text('Residencial Luna'), findsOneWidget);
  });
}
