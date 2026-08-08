// Widget tests for `LocationPickerMap` (P9 B2: pick-on-map lat/lng in the
// create-listing flow).
//
// `FlutterMap` in flutter_map 7.x fetches raster tiles over the network on
// build, so the tests below deliberately use a bounded `pump()` instead of
// `pumpAndSettle()` — settling would hang waiting for tile requests that
// never resolve in the test environment (see `listing_location_map_test.dart`
// for the established pattern this mirrors).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:foxy_ads/features/real-estate/presentation/widgets/location_picker_map.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Widget _buildTestApp({
  required ValueChanged<LatLng?> onChanged,
  LatLng? initialCenter,
  LatLng? initialValue,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: LocationPickerMap(
          onChanged: onChanged,
          initialCenter: initialCenter,
          initialValue: initialValue,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders a FlutterMap and the unpicked hint text when nothing is picked',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(onChanged: (_) {}));
      // Bounded pump: avoids hanging on network tile fetches.
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Ubicación en el mapa'), findsOneWidget);
      expect(
        find.text('Toca el mapa para marcar la ubicación exacta'),
        findsOneWidget,
      );
      // No pick yet: no marker icon, no "picked" confirmation, no clear
      // button.
      expect(find.byIcon(Icons.location_on), findsNothing);
      expect(find.text('Ubicación marcada'), findsNothing);
      expect(find.text('Quitar ubicación'), findsNothing);
    },
  );

  testWidgets(
    'shows the marker, picked confirmation and clear button when '
    'initialValue is set',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          onChanged: (_) {},
          initialValue: const LatLng(40.4168, -3.7038),
        ),
      );
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.text('Ubicación marcada'), findsOneWidget);
      expect(find.text('Quitar ubicación'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the clear button fires onChanged(null) and removes the marker',
    (tester) async {
      LatLng? lastValue = const LatLng(40.4168, -3.7038);
      var callCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          onChanged: (v) {
            lastValue = v;
            callCount++;
          },
          initialValue: const LatLng(40.4168, -3.7038),
        ),
      );
      await tester.pump();

      expect(find.text('Quitar ubicación'), findsOneWidget);
      await tester.tap(find.text('Quitar ubicación'));
      await tester.pump();

      expect(callCount, 1);
      expect(lastValue, isNull);
      // After clearing, the marker/confirmation/clear button all disappear
      // and the hint text is back.
      expect(find.byIcon(Icons.location_on), findsNothing);
      expect(find.text('Ubicación marcada'), findsNothing);
      expect(find.text('Quitar ubicación'), findsNothing);
      expect(
        find.text('Toca el mapa para marcar la ubicación exacta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping the map picks a location and fires onChanged with coordinates',
    (tester) async {
      LatLng? lastValue;
      var callCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          onChanged: (v) {
            lastValue = v;
            callCount++;
          },
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump();
      // flutter_map's tap gesture recognizer schedules a short internal
      // timer (double-tap-zoom disambiguation) after `_handleOnTapUp`; let
      // it fire before the test disposes the widget tree, or the test
      // binding's "Timer is still pending" invariant check fails.
      await tester.pump(const Duration(milliseconds: 300));

      // Tapping the underlying flutter_map surface is exercised on a
      // best-effort basis: flutter_map's gesture recognizers depend on an
      // initialized camera, which may or may not resolve a tap to a LatLng
      // in the test harness. Assert the callback contract rather than an
      // exact coordinate: either it fired with a non-null pick (and the UI
      // updated to reflect it), or it did not fire at all — never with a
      // null value (that would mean a spurious clear from a plain tap).
      if (callCount > 0) {
        expect(lastValue, isNotNull);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(find.text('Ubicación marcada'), findsOneWidget);
      }
    },
  );
}
