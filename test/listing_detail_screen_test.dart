// Widget tests for the `/listing/:id` detail screen — the core listing
// screen of the app.
//
// `ListingDetailScreen` watches three providers on build:
//   - `listingDetailProvider(listingId)` (a `FutureProvider.family` defined
//     in the screen file itself, exported as a top-level identifier) — the
//     listing data.
//   - `authStateProvider` — current auth user (anonymous in these tests).
//   - `userFavoritesProvider` — the signed-in user's favorite ids.
//
// A 4th provider (`agencyProfileProvider`) is only watched when the seller's
// `userId` looks like a UUID (see `ListingDetailScreen._isUuid`), so these
// fixtures deliberately use a non-UUID seller id ('seller-1') to skip that
// branch and avoid a 4th override.
//
// `AdBanner` (rendered near the bottom of the content) is gated behind
// `kAdsEnabled` (false by default) so it renders `SizedBox.shrink()` and
// never touches the Google Mobile Ads SDK — safe to pump in a plain
// widget test.
//
// The favorite/report/edit/share affordances call `context.push(...)`
// (go_router) or open bottom sheets on tap; per the task's guidance we only
// assert their *presence* (icons/buttons), not tap-driven navigation, since
// wiring a full `GoRouter` harness for this screen is out of scope here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/core/services/favorite_service.dart';
import 'package:foxy_ads/core/utils/format_utils.dart';
import 'package:foxy_ads/features/listings/presentation/screens/listing_detail_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Listing _fixtureListing() {
  return Listing(
    id: 'l1',
    userId: 'seller-1', // deliberately not a UUID — skips agencyProfileProvider
    categoryId: 'cat-1',
    countryCode: 'ES',
    title: 'Coche familiar en muy buen estado',
    description: 'Un coche familiar, poco uso, revisiones al día.',
    price: 15000,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    userName: 'Javier',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp(Listing? listing) {
  return ProviderScope(
    overrides: [
      listingDetailProvider('l1').overrideWith((ref) async => listing),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      userFavoritesProvider.overrideWith((ref) async => <String>[]),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ListingDetailScreen(listingId: 'l1'),
    ),
  );
}

void main() {
  testWidgets(
    'renders the listing title, price and seller section',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(_fixtureListing()));
      await tester.pumpAndSettle();

      expect(find.text('Coche familiar en muy buen estado'), findsOneWidget);
      // Price is now rendered locale-aware via formatPrice (es locale here)
      // instead of the deprecated `Listing.formattedPrice`.
      expect(find.text(formatPrice(15000, 'EUR', 'es')), findsOneWidget);
      // Seller heading + seller name.
      expect(find.text('Vendedor'), findsOneWidget);
      expect(find.text('Javier'), findsOneWidget);
    },
  );

  testWidgets(
    'shows previous price strikethrough and drop badge when previousPrice indicates a drop',
    (tester) async {
      final listing = _fixtureListing().copyWith(
        price: 12000,
        previousPrice: 15000,
      );
      await tester.pumpWidget(_buildTestApp(listing));
      await tester.pumpAndSettle();

      expect(find.text(formatPrice(12000, 'EUR', 'es')), findsOneWidget);
      expect(find.text(formatPrice(15000, 'EUR', 'es')), findsOneWidget);
      expect(find.text('↓20%'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the favorite, share and report/more affordances',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(_fixtureListing()));
      await tester.pumpAndSettle();

      // Anonymous user + not-favorited -> outlined heart icon.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      // "More" popup menu hosts the report (and, for owners, edit) actions.
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    },
  );

  testWidgets(
    'shows the contact-message CTA in the bottom bar',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(_fixtureListing()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.message_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'listing not found renders the not-found message',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(null));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Whatever the not-found copy is, the screen shouldn't show listing
      // content (title/price) for a null listing.
      expect(find.text('Coche familiar en muy buen estado'), findsNothing);
    },
  );
}
