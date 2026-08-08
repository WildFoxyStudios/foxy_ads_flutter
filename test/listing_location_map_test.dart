// Widget tests for `ListingLocationMap` (Task A4 of the P9 sprint).
//
// `FlutterMap` in flutter_map 7.x fetches raster tiles over the network on
// build, so the tests below deliberately use a bounded `pump()` instead of
// `pumpAndSettle()` — settling would hang waiting for tile requests that
// never resolve in the test environment (see `re_map_view.dart` for the
// production widget this mirrors; there is no existing flutter_map test in
// this suite to follow, so this establishes the pattern).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/listings/presentation/widgets/listing_location_map.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _fixtureListing({double? latitude, double? longitude}) {
  return Listing(
    id: 'l1',
    userId: 'seller-1',
    categoryId: 'real_estate',
    countryCode: 'ES',
    title: 'Piso luminoso en el centro',
    description: 'Un piso muy luminoso, cerca de todo.',
    price: 150000,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    userName: 'Javier',
    createdAt: DateTime(2026, 1, 1),
    latitude: latitude,
    longitude: longitude,
  );
}

Widget _buildTestApp(Listing listing) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: ListingLocationMap(listing: listing),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders a FlutterMap when the listing has coordinates',
    (tester) async {
      final listing = _fixtureListing(latitude: 40.4168, longitude: -3.7038);
      await tester.pumpWidget(_buildTestApp(listing));
      // Bounded pump: avoids hanging on network tile fetches.
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    },
  );

  testWidgets(
    'renders nothing when the listing has no coordinates',
    (tester) async {
      final listing = _fixtureListing();
      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pump();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Ubicación'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    },
  );
}
