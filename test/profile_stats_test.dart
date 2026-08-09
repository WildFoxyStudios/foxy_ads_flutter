// Widget + unit tests for the profile-header stats row and member-since
// line (P10 C2).
//
// `ProfileScreen` derives its stats row from `myListingsProvider` (the same
// FutureProvider `/my-listings` uses — see `my_listings_screen.dart`) via
// the pure `deriveProfileStats` function, so most of the logic is covered
// directly against that function. One widget test drives the full screen to
// confirm the tiles + member-since line actually render, following the
// override pattern from `edit_profile_screen_test.dart` (`currentUserProvider`
// overridden directly) and `dark_mode_leak_test.dart` (`authStateProvider`
// overridden with a signed-in `User` stream, `selectedCountryProvider`
// overridden with a fake `Notifier` so no `SharedPreferences` platform
// channel is touched).
//
// `myAgencyProfileProvider` is overridden to resolved `null` so the
// "Panel Pro" tile's `Builder` doesn't attempt a real Supabase round-trip.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/models/user_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/agency/data/agency_service.dart';
import 'package:foxy_ads/features/profile/presentation/screens/my_listings_screen.dart'
    show myListingsProvider;
import 'package:foxy_ads/features/profile/presentation/screens/profile_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _listing({
  required String id,
  required String status,
  required int views,
}) {
  return Listing(
    id: id,
    userId: 'u1',
    categoryId: 'cat-1',
    countryCode: 'ES',
    title: 'Listing $id',
    description: 'desc',
    price: 100,
    currency: 'EUR',
    images: const <String>[],
    status: status,
    views: views,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// 3 active, 1 sold, 1 inactive; views 10+5+3+2+0 = 20.
List<Listing> _fixtureListings() => [
      _listing(id: 'l1', status: 'active', views: 10),
      _listing(id: 'l2', status: 'active', views: 5),
      _listing(id: 'l3', status: 'active', views: 3),
      _listing(id: 'l4', status: 'sold', views: 2),
      _listing(id: 'l5', status: 'inactive', views: 0),
    ];

AppUser _userFixture() {
  return AppUser(
    id: 'u1',
    email: 'javier@example.com',
    name: 'Javier',
    createdAt: DateTime(2026, 1, 15),
  );
}

User _signedInUser() {
  return User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-15T00:00:00Z',
  );
}

/// Overrides `SelectedCountryNotifier.build()` so no `SharedPreferences`
/// platform channel is touched during the test (mirrors
/// `dark_mode_leak_test.dart`'s `_FakeCountryNotifier`).
class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => Country.defaultCountries.first;
}

Widget _buildTestApp(
  Future<List<Listing>> Function(Ref ref) myListings,
) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_signedInUser())),
      currentUserProvider.overrideWith((ref) async => _userFixture()),
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      myAgencyProfileProvider.overrideWith((ref) async => null),
      myListingsProvider.overrideWith(myListings),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProfileScreen(),
    ),
  );
}

void main() {
  group('deriveProfileStats (pure function)', () {
    test('counts total/active/sold and sums views, excluding deleted', () {
      final stats = deriveProfileStats(_fixtureListings());

      expect(stats.total, 5);
      expect(stats.active, 3);
      expect(stats.sold, 1);
      expect(stats.views, 20);
    });

    test('excludes deleted listings from every count', () {
      final listings = [
        ..._fixtureListings(),
        _listing(id: 'l6', status: 'deleted', views: 100),
      ];

      final stats = deriveProfileStats(listings);

      expect(stats.total, 5);
      expect(stats.active, 3);
      expect(stats.sold, 1);
      expect(stats.views, 20);
    });

    test('all-zero for an empty listing set', () {
      final stats = deriveProfileStats(const <Listing>[]);

      expect(stats.total, 0);
      expect(stats.active, 0);
      expect(stats.sold, 0);
      expect(stats.views, 0);
    });
  });

  group('ProfileScreen stats row + member-since (widget)', () {
    testWidgets(
      'renders Total/Activos/Vendidos/Vistas from the user listings',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp((ref) async => _fixtureListings()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total'), findsOneWidget);
        expect(find.text('Activos'), findsOneWidget);
        expect(find.text('Vendidos'), findsOneWidget);
        expect(find.text('Vistas'), findsOneWidget);

        expect(find.text('5'), findsOneWidget); // total
        expect(find.text('3'), findsOneWidget); // active
        expect(find.text('1'), findsOneWidget); // sold
        expect(find.text('20'), findsOneWidget); // views
      },
    );

    testWidgets(
      'renders the member-since line from the user account creation date',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp((ref) async => _fixtureListings()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Miembro desde Ene 2026'), findsOneWidget);
      },
    );

    testWidgets(
      'shows dash placeholders while the listings are still loading',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp((ref) => Completer<List<Listing>>().future,),
        );
        // Single pump: the stats provider is still resolving. Don't
        // `pumpAndSettle` — the fake future never completes.
        await tester.pump();

        expect(find.text('-'), findsNWidgets(4));
      },
    );

    // Note: the error branch (`_ProfileStatsRow` → `error: SizedBox.shrink()`,
    // profile_screen.dart) hides the whole stats row when the listings fetch
    // fails, so a broken fetch never surfaces a half-empty row. It is not
    // exercised as a widget test here because a throwing FutureProvider
    // override disrupts `pumpAndSettle`'s error propagation in the harness;
    // the branch is a trivial `SizedBox.shrink()` verified by inspection.
  });
}
