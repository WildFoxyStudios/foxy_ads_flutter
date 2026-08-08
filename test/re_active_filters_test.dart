// Widget tests for ReActiveFilters (Task 9 of the RE parity sprint).
//
// Covers:
//   - Hidden (SizedBox.shrink()) when no filters are active.
//   - One ActiveFilterChip per VALUE (2 property types + 1 city + 1 price
//     range == 4 chips), plus a "Limpiar todo" button that is NOT an
//     ActiveFilterChip.
//   - Tapping a property-type chip's delete icon removes just that value
//     from the notifier and keeps the other.
//   - Tapping the price-range chip's delete icon clears BOTH priceMin and
//     priceMax in the notifier and fires onRangeCleared(ReRangeField.price).
//
// Pattern follows search_screen_empty_state_test.dart: a real
// ProviderContainer (not a mocked provider) with selectedCountryProvider
// overridden to a fixed country so the widget never touches
// SharedPreferences, wrapped in UncontrolledProviderScope so the test can
// read the *real* reSearchFiltersProvider notifier before/after taps.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/features/real-estate/presentation/providers/re_search_provider.dart';
import 'package:foxy_ads/features/real-estate/presentation/widgets/re_active_filters.dart';
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

ProviderContainer _buildContainer() {
  final container = ProviderContainer(
    overrides: [
      selectedCountryProvider.overrideWith(
        () => _FakeCountryNotifier(_testCountry),
      ),
    ],
  );
  return container;
}

Widget _pump(
  ProviderContainer container, {
  required void Function(ReRangeField) onRangeCleared,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReActiveFilters(onRangeCleared: onRangeCleared),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when no filters are active', (tester) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_pump(container, onRangeCleared: (_) {}));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveFilterChip), findsNothing);
    expect(find.text('Limpiar todo'), findsNothing);
  });

  testWidgets(
    'renders one chip per value plus a Limpiar todo button',
    (tester) async {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reSearchFiltersProvider.notifier);
      notifier.toggleString('propertyTypes', value: 'piso');
      notifier.toggleString('propertyTypes', value: 'casa');
      notifier.setCity('Madrid');
      notifier.setPriceMin(1000);
      notifier.setPriceMax(5000);

      await tester.pumpWidget(_pump(container, onRangeCleared: (_) {}));
      await tester.pumpAndSettle();

      // 2 property types + 1 city + 1 price range == 4 chips.
      expect(find.byType(ActiveFilterChip), findsNWidgets(4));
      // "Limpiar todo" renders as a TextButton, not an ActiveFilterChip.
      expect(find.widgetWithText(TextButton, 'Limpiar todo'), findsOneWidget);
      expect(find.text('Piso'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Madrid'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting a property-type chip removes only that value',
    (tester) async {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reSearchFiltersProvider.notifier);
      notifier.toggleString('propertyTypes', value: 'piso');
      notifier.toggleString('propertyTypes', value: 'casa');
      notifier.setCity('Madrid');
      notifier.setPriceMin(1000);
      notifier.setPriceMax(5000);

      await tester.pumpWidget(_pump(container, onRangeCleared: (_) {}));
      await tester.pumpAndSettle();

      final pisoChip = find.widgetWithText(InputChip, 'Piso');
      expect(pisoChip, findsOneWidget);
      final deleteIcon = find.descendant(
        of: pisoChip,
        matching: find.byIcon(Icons.close),
      );
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      final filters = container.read(reSearchFiltersProvider);
      expect(filters.propertyTypes, ['casa']);
      expect(find.byType(ActiveFilterChip), findsNWidgets(3));
    },
  );

  testWidgets(
    'deleting the price-range chip clears both bounds and notifies the screen',
    (tester) async {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reSearchFiltersProvider.notifier);
      notifier.toggleString('propertyTypes', value: 'piso');
      notifier.setPriceMin(1000);
      notifier.setPriceMax(5000);

      final cleared = <ReRangeField>[];
      await tester.pumpWidget(
        _pump(container, onRangeCleared: cleared.add),
      );
      await tester.pumpAndSettle();

      // 'Piso' is the only other chip, so the remaining InputChip's label
      // text identifies the price-range chip.
      final chipWidgets = tester.widgetList<InputChip>(
        find.byType(InputChip),
      );
      expect(chipWidgets.length, 2);
      final priceLabel = chipWidgets
          .map((c) => (c.label as Text).data!)
          .firstWhere((text) => text != 'Piso');

      final priceChip = find.widgetWithText(InputChip, priceLabel);
      final deleteIcon = find.descendant(
        of: priceChip,
        matching: find.byIcon(Icons.close),
      );
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      final filters = container.read(reSearchFiltersProvider);
      expect(filters.priceMin, isNull);
      expect(filters.priceMax, isNull);
      expect(cleared, [ReRangeField.price]);
    },
  );

  testWidgets('Limpiar todo clears every filter and both ranges', (
    tester,
  ) async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    final notifier = container.read(reSearchFiltersProvider.notifier);
    notifier.toggleString('propertyTypes', value: 'piso');
    notifier.setCity('Madrid');
    notifier.setPriceMin(1000);
    notifier.setPriceMax(5000);
    notifier.setM2Min(50);
    notifier.setM2Max(120);

    final cleared = <ReRangeField>[];
    await tester.pumpWidget(_pump(container, onRangeCleared: cleared.add));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Limpiar todo'));
    await tester.pumpAndSettle();

    final filters = container.read(reSearchFiltersProvider);
    expect(filters.isActive, isFalse);
    expect(cleared, containsAll([ReRangeField.price, ReRangeField.area]));
    expect(find.byType(ActiveFilterChip), findsNothing);
  });
}
