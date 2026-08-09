// Widget tests for `DevelopmentLocationMap` (Plan 11, F4: embedded location
// mini-map on the development/promotion detail screen).
//
// `FlutterMap` in flutter_map 7.x fetches raster tiles over the network on
// build, so the tests below deliberately use a bounded `pump()` instead of
// `pumpAndSettle()` — settling would hang waiting for tile requests that
// never resolve in the test environment (see
// `test/listing_location_map_test.dart`, which this mirrors).

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/developments/presentation/widgets/development_location_map.dart';

Widget _buildTestApp({double? latitude, double? longitude}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 600,
        child: DevelopmentLocationMap(
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders a FlutterMap when the development has coordinates',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(latitude: 40.4168, longitude: -3.7038),
      );
      // Bounded pump: avoids hanging on network tile fetches.
      await tester.pump();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    },
  );

  testWidgets(
    'renders nothing when the development has no coordinates',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.byType(FlutterMap), findsNothing);
    },
  );

  testWidgets(
    'renders nothing when coordinates are (0, 0)',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(latitude: 0, longitude: 0));
      await tester.pump();

      expect(find.byType(FlutterMap), findsNothing);
    },
  );
}
