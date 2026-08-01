// Widget tests for the Pro Dashboard gate at `/panel` (Task 5 of the
// B2B/agency sprint).
//
// Covers the two rendering paths of `PanelScreen`:
//   - Case A: `myAgencyProfileProvider` resolves to `null` (no profile yet)
//     -> the "Panel Pro" explainer is shown, the Stats section is NOT.
//   - Case B: `myAgencyProfileProvider` resolves to a verified profile
//     -> the dashboard renders, the Stats section is present (assert a
//     stats label like "Total" is found).
//
// We override `myAgencyProfileProvider` directly with an `AsyncData` so the
// test does NOT need a real Supabase client — no `supabaseClientProvider`
// overrides. The two panel-data providers (`myPanelListingsProvider`,
// `panelFavoritesProvider`) are also overridden in Case B so the verified
// branch renders an empty-but-valid stats grid without a real DB round trip.
// Case B also overrides `authStateProvider` with a signed-in user stream so
// the screen reaches the verified branch (the screen short-circuits to the
// "Inicia sesión" gate when no user is present).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/agency/data/agency_model.dart';
import 'package:foxy_ads/features/agency/data/agency_service.dart';
import 'package:foxy_ads/features/agency/data/panel_stats.dart';
import 'package:foxy_ads/features/agency/presentation/screens/panel_screen.dart';

AgencyProfile _verifiedProfile() {
  return AgencyProfile(
    userId: 'agency-1',
    name: 'Fox Real Estate',
    createdAt: '2026-01-01T00:00:00.000Z',
    isVerified: true,
  );
}

User _stubUser() {
  // `User` is a real Supabase type; the panel screen only reads `.id` and
  // checks for null. The other fields can be empty for this test.
  return User(
    id: 'agency-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'agency@example.com',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );
}

Widget _buildTestApp({
  required AsyncValue<AgencyProfile?> profileOverride,
  User? signedInUser,
  List<Listing> panelListings = const [],
  Map<String, int> panelFavorites = const {},
  List<DayPoint> viewsSeries = const [],
}) {
  final overrides = [
    myAgencyProfileProvider.overrideWith(
      (ref) async => profileOverride.value,
    ),
    myPanelListingsProvider.overrideWith((ref) async => panelListings),
    panelFavoritesProvider.overrideWith((ref) async => panelFavorites),
    // Override so the new views chart (Task 6) doesn't try to hit the
    // RPC during tests. `const []` triggers the chart's "Sin datos"
    // placeholder, which is fine for the gate test.
    viewsSeriesProvider.overrideWith((ref) async => viewsSeries),
  ];
  if (signedInUser != null) {
    overrides.add(
      authStateProvider.overrideWith((ref) => Stream.value(signedInUser)),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: PanelScreen()),
  );
}

void main() {
  testWidgets(
    'Case A: shows "Panel Pro" explainer when profile is null',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          profileOverride: const AsyncValue<AgencyProfile?>.data(null),
          signedInUser: _stubUser(),
        ),
      );
      await tester.pumpAndSettle();

      // The explainer heading must be visible (AppBar + heading both say
      // "Panel Pro", so we expect 2 occurrences).
      expect(find.text('Panel Pro'), findsNWidgets(2));

      // The stats section must NOT be present. Asserting on a stats
      // label keeps the test stable if the explainer copy evolves.
      expect(find.text('Total anuncios'), findsNothing);
    },
  );

  testWidgets(
    'Case B: shows stats when profile is verified',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          profileOverride: AsyncValue<AgencyProfile?>.data(_verifiedProfile()),
          signedInUser: _stubUser(),
        ),
      );
      await tester.pumpAndSettle();

      // Stats section must be present — a tile label.
      expect(find.text('Total anuncios'), findsOneWidget);
      // The explainer heading must NOT be visible.
      expect(find.text('Panel Pro'), findsOneWidget); // AppBar only
    },
  );
}

