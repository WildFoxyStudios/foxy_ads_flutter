// Widget tests for the public `/agencia/:id` profile screen (Task 3 of the
// B2B/agency sprint).
//
// Covers three rendering paths:
//   - Profile not found (fetchAgencyProfile returns null) -> renders the
//     "Agencia no encontrada" empty state (no listings grid).
//   - Profile + empty listings -> renders the listings empty-state text.
//   - Profile + 2 listings -> exactly 2 ListingCard widgets are rendered.
//
// Follows the same fake-SupabaseClient(`autoRefreshToken:false`) +
// ProviderScope override pattern used in `test/promociones_screen_test.dart`.
// `FakeAgencyService` extends `AgencyService` (NOT a wrapper) so the providers
// (which expose a real `AgencyService` reference) accept the override.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/features/agency/data/agency_model.dart';
import 'package:foxy_ads/features/agency/data/agency_service.dart';
import 'package:foxy_ads/features/agency/presentation/screens/agency_profile_screen.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';

/// Fake `AgencyService` that ignores Supabase entirely and returns whatever
/// the test set up. Overrides `fetchAgencyProfile` + `fetchAgencyListings`;
/// the dummy `SupabaseClient` is never invoked.
class FakeAgencyService extends AgencyService {
  FakeAgencyService(
    super.supabase, {
    required this.profile,
    required this.listings,
  });

  AgencyProfile? profile;
  List<Listing> listings;
  bool hasMore = false;

  @override
  Future<AgencyProfile?> fetchAgencyProfile(String userId) async {
    return profile;
  }

  @override
  Future<({List<Listing> items, bool hasMore})> fetchAgencyListings(
    String userId,
    int page,
  ) async {
    return (items: listings, hasMore: hasMore);
  }
}

AgencyProfile _profile({
  String name = 'Fox Real Estate',
  bool verified = true,
}) {
  return AgencyProfile(
    userId: 'agency-1',
    name: name,
    createdAt: '2026-01-01T00:00:00.000Z',
    logoUrl: null,
    description:
        'Agencia inmobiliaria especializada en obra nueva en la costa mediterránea.',
    website: 'https://example.com',
    phone: '+34 600 000 000',
    location: 'Madrid, España',
    isVerified: verified,
  );
}

Listing _listing(String id, String title) {
  return Listing(
    id: id,
    userId: 'agency-1',
    categoryId: 'cat-1',
    countryCode: 'ES',
    title: title,
    description: 'desc',
    price: 100000,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp(FakeAgencyService fake) {
  return ProviderScope(
    overrides: [
      agencyServiceProvider.overrideWithValue(fake),
    ],
    child: const MaterialApp(
      home: AgencyProfileScreen(agencyId: 'agency-1'),
    ),
  );
}

void main() {
  testWidgets(
    'shows "Agencia no encontrada" when profile is null',
    (tester) async {
      final fake = FakeAgencyService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        profile: null,
        listings: const [],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      expect(find.text('Agencia no encontrada'), findsOneWidget);
      expect(find.byType(ListingCard), findsNothing);
    },
  );

  testWidgets(
    'shows empty-state when profile exists but has no listings',
    (tester) async {
      final fake = FakeAgencyService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        profile: _profile(),
        listings: const [],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay anuncios'), findsOneWidget);
      expect(find.byType(ListingCard), findsNothing);
    },
  );

  testWidgets(
    'shows 2 ListingCards when 2 listings are returned',
    (tester) async {
      final fake = FakeAgencyService(
        SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
        profile: _profile(),
        listings: [
          _listing('l-1', 'Piso en Madrid centro'),
          _listing('l-2', 'Ático con terraza'),
        ],
      );

      await tester.pumpWidget(_buildTestApp(fake));
      await tester.pumpAndSettle();

      expect(find.byType(ListingCard), findsNWidgets(2));
      expect(find.text('Piso en Madrid centro'), findsOneWidget);
      expect(find.text('Ático con terraza'), findsOneWidget);
    },
  );
}
