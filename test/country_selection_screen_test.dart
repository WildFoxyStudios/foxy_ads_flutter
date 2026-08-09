// Widget tests for the `/settings/country` screen (Sprint 12 Task 4).
//
// `CountrySelectionScreen` watches two providers:
//   - `countriesProvider` (FutureProvider) — the list to render.
//   - `selectedCountryProvider` (NotifierProvider<SelectedCountryNotifier>)
//     — which entry is highlighted.
//
// Tapping a row calls `SelectedCountryNotifier.setCountry(country)` (which
// touches `SharedPreferences` in the real implementation) and then
// `context.pop()`. Per the established pattern (see
// `dark_mode_leak_test.dart`, `valuation_screen_test.dart`,
// `promote_listing_screen_test.dart`), `SelectedCountryNotifier.build()` is
// overridden so no `SharedPreferences` platform channel is touched; here we
// additionally override `setCountry` (still updating `state`, still
// recording the call) so the tap test doesn't need a real prefs backend
// either, and a real `GoRouter` with a route to pop back to is wired up so
// `context.pop()` doesn't crash for lack of a `GoRouter` in the tree.
//
// A `ProviderContainer` + `UncontrolledProviderScope` (the same combination
// already used for provider-only tests in this repo, e.g.
// `theme_mode_test.dart`) lets the test read the notifier's state/call log
// straight from the container after the tap, instead of re-deriving it from
// widget text.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/features/settings/presentation/screens/country_selection_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _spain = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

final _france = Country(
  code: 'FR',
  name: 'Francia',
  flag: '🇫🇷',
  currency: 'EUR',
  currencySymbol: '€',
);

final _germany = Country(
  code: 'DE',
  name: 'Alemania',
  flag: '🇩🇪',
  currency: 'EUR',
  currencySymbol: '€',
);

/// Overrides `build()` (no SharedPreferences read) and `setCountry` (no
/// SharedPreferences write) while still updating `state` and recording the
/// call, so the tap-to-select flow is fully observable without a prefs
/// backend.
class _FakeCountryNotifier extends SelectedCountryNotifier {
  _FakeCountryNotifier(this._initial);
  final Country _initial;
  final List<Country> setCountryCalls = [];

  @override
  Country build() => _initial;

  @override
  Future<void> setCountry(Country country) async {
    setCountryCalls.add(country);
    state = country;
  }
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/root',
    routes: [
      GoRoute(
        path: '/root',
        builder: (c, s) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/country',
        builder: (c, s) => const CountrySelectionScreen(),
      ),
    ],
  );
}

Widget _buildTestApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'renders each country with a highlighted selected row',
    (tester) async {
      final notifier = _FakeCountryNotifier(_spain);
      final container = ProviderContainer(
        overrides: [
          selectedCountryProvider.overrideWith(() => notifier),
          countriesProvider.overrideWith((ref) async => [_spain, _france]),
        ],
      );
      addTearDown(container.dispose);
      final router = _buildRouter();

      await tester.pumpWidget(_buildTestApp(container, router));
      router.push('/country');
      await tester.pumpAndSettle();

      expect(find.text('España'), findsOneWidget);
      expect(find.text('Francia'), findsOneWidget);
      // The selected row (España) shows a check-circle; the other shows a
      // plain forward chevron.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a country calls setCountry, updates selectedCountryProvider, and pops back',
    (tester) async {
      final notifier = _FakeCountryNotifier(_spain);
      final container = ProviderContainer(
        overrides: [
          selectedCountryProvider.overrideWith(() => notifier),
          countriesProvider.overrideWith((ref) async => [_spain, _france]),
        ],
      );
      addTearDown(container.dispose);
      final router = _buildRouter();

      await tester.pumpWidget(_buildTestApp(container, router));
      router.push('/country');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Francia'));
      await tester.pumpAndSettle();

      expect(notifier.setCountryCalls, hasLength(1));
      expect(notifier.setCountryCalls.single.code, 'FR');
      expect(container.read(selectedCountryProvider).code, 'FR');
      // Popped back to the root route — the country list is gone.
      expect(find.byType(CountrySelectionScreen), findsNothing);
    },
  );

  testWidgets(
    'shows the error state with a retry button when countriesProvider throws',
    (tester) async {
      final notifier = _FakeCountryNotifier(_spain);
      final container = ProviderContainer(
        overrides: [
          selectedCountryProvider.overrideWith(() => notifier),
          countriesProvider.overrideWith(
            (ref) async => throw Exception('network down'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _buildRouter();

      await tester.pumpWidget(_buildTestApp(container, router));
      router.push('/country');
      await tester.pumpAndSettle();

      expect(find.text('Error al cargar países'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets(
    'renders a search field and filters the country list by name as the user types',
    (tester) async {
      final notifier = _FakeCountryNotifier(_spain);
      final container = ProviderContainer(
        overrides: [
          selectedCountryProvider.overrideWith(() => notifier),
          countriesProvider.overrideWith(
            (ref) async => [_spain, _france, _germany],
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _buildRouter();

      await tester.pumpWidget(_buildTestApp(container, router));
      router.push('/country');
      await tester.pumpAndSettle();

      // Search field renders, all three countries visible initially.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('España'), findsOneWidget);
      expect(find.text('Francia'), findsOneWidget);
      expect(find.text('Alemania'), findsOneWidget);

      // Typing "esp" (case-insensitive, name match) filters down to España.
      await tester.enterText(find.byType(TextField), 'esp');
      await tester.pumpAndSettle();

      expect(find.text('España'), findsOneWidget);
      expect(find.text('Francia'), findsNothing);
      expect(find.text('Alemania'), findsNothing);
    },
  );

  testWidgets(
    'filters by country code and shows a no-results message when nothing matches',
    (tester) async {
      final notifier = _FakeCountryNotifier(_spain);
      final container = ProviderContainer(
        overrides: [
          selectedCountryProvider.overrideWith(() => notifier),
          countriesProvider.overrideWith(
            (ref) async => [_spain, _france, _germany],
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = _buildRouter();

      await tester.pumpWidget(_buildTestApp(container, router));
      router.push('/country');
      await tester.pumpAndSettle();

      // Matching by country code (case-insensitive).
      await tester.enterText(find.byType(TextField), 'de');
      await tester.pumpAndSettle();
      expect(find.text('Alemania'), findsOneWidget);
      expect(find.text('España'), findsNothing);
      expect(find.text('Francia'), findsNothing);

      // No match -> "no results" message.
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('España'), findsNothing);
      expect(find.text('Francia'), findsNothing);
      expect(find.text('Alemania'), findsNothing);
      expect(find.text('Sin resultados'), findsOneWidget);
    },
  );
}
