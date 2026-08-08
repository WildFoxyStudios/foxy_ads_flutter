// Widget tests for ListingCard (Sprint 7 Plan 7 Task 2).
//
// Locks behavior for the price + posted-date row wiring and guards against
// RenderFlex overflow at the standard text scale (1.0) and the accessibility
// large-text scale (1.3) used by the production grids (home, all_listings,
// category_listings, favorites).
//
// Pattern: pump a real `ListingCard` inside a `MaterialApp` with
// `AppLocalizations.localizationsDelegates` + `supportedLocales`. No fake
// service needed — `ListingCard` only depends on a `Listing` instance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/utils/format_utils.dart';
import 'package:foxy_ads/features/home/presentation/widgets/listing_card.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Listing fixture for the locale-price + date-row assertions. The price is
/// 1234 so both the es (`1.234`) and en (`1,234`) locale groupings are
/// exercised; `createdAt` is 3 days ago so the date row renders a "days"
/// bucket (locale-aware via `formatCardDate`).
Listing _listingFixture() {
  return Listing(
    id: 'l-1',
    userId: 'seller-1',
    categoryId: 'vehicles',
    countryCode: 'ES',
    title: 'Coche en venta',
    description: 'Un coche muy bueno.',
    price: 1234,
    currency: 'EUR',
    images: const [],
    city: 'Madrid',
    categoryName: 'Vehículos',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  );
}

Widget _wrap({
  required Widget home,
  required Locale locale,
  double textScaler = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaler)),
      child: Scaffold(body: Center(child: SizedBox(width: 400, height: 600, child: home))),
    ),
  );
}

/// Captures every FlutterError for the duration of [body] and returns the
/// list of error strings so the test can assert no RenderFlex overflow was
/// reported. Restores the previous `FlutterError.onError` in a finally
/// block so a failed assertion does not leak the override to other tests.
Future<List<String>> _captureFlutterErrors(Future<void> Function() body) async {
  final previous = FlutterError.onError;
  final captured = <String>[];
  FlutterError.onError = (details) {
    captured.add(details.exceptionAsString());
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return captured;
}

void main() {
  group('ListingCard locale-aware price', () {
    testWidgets('renders es grouping under es locale', (tester) async {
      await tester.pumpWidget(
        _wrap(locale: const Locale('es'), home: ListingCard(listing: _listingFixture(), onTap: () {})),
      );
      await tester.pumpAndSettle();

      final priceFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(formatPrice(1234, 'EUR', 'es').split(' ').first),
      );
      expect(priceFinder, findsOneWidget);
      final priceText = (tester.widget<Text>(priceFinder)).data!;
      expect(priceText, contains('1.234'));
      expect(priceText, isNot(contains(',')));
    });

    testWidgets('renders en grouping under en locale', (tester) async {
      await tester.pumpWidget(
        _wrap(locale: const Locale('en'), home: ListingCard(listing: _listingFixture(), onTap: () {})),
      );
      await tester.pumpAndSettle();

      final priceFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(formatPrice(1234, 'EUR', 'en').split(' ').first),
      );
      expect(priceFinder, findsOneWidget);
      final priceText = (tester.widget<Text>(priceFinder)).data!;
      expect(priceText, contains('1,234'));
      expect(priceText, isNot(contains('.')));
    });

    testWidgets('price text differs between es and en', (tester) async {
      await tester.pumpWidget(
        _wrap(locale: const Locale('es'), home: ListingCard(listing: _listingFixture(), onTap: () {})),
      );
      await tester.pumpAndSettle();
      final esPrice = (tester.widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('€'),
      ))).data!;

      await tester.pumpWidget(
        _wrap(locale: const Locale('en'), home: ListingCard(listing: _listingFixture(), onTap: () {})),
      );
      await tester.pumpAndSettle();
      final enPrice = (tester.widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('€'),
      ))).data!;

      expect(esPrice, isNot(equals(enPrice)));
    });
  });

  group('ListingCard posted-date row', () {
    testWidgets('renders a localized date label below the city', (tester) async {
      final listing = _listingFixture();
      await tester.pumpWidget(
        _wrap(locale: const Locale('es'), home: ListingCard(listing: listing, onTap: () {})),
      );
      await tester.pumpAndSettle();

      // Compute the expected label the same way the widget does, so the
      // assertion is locale-agnostic. 3 days ago → "Hace 3 días".
      final l10n = await AppLocalizations.delegate.load(const Locale('es'));
      final expected = formatCardDate(listing.createdAt, l10n);
      expect(expected, isNotEmpty);

      expect(find.text(expected), findsAtLeastNWidgets(1));
      // The clock icon anchors the date row visually.
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });
  });

  group('ListingCard layout overflow', () {
    testWidgets('does not overflow at textScaler 1.0', (tester) async {
      final errors = await _captureFlutterErrors(() async {
        await tester.pumpWidget(
          _wrap(
            locale: const Locale('es'),
            home: ListingCard(listing: _listingFixture(), onTap: () {}),
          ),
        );
        await tester.pumpAndSettle();
      });
      final overflows = errors.where((e) => e.contains('RenderFlex')).toList();
      expect(
        overflows,
        isEmpty,
        reason: 'ListingCard overflowed at textScaler 1.0 — consider adjusting '
            'childAspectRatio in the 4 production grids. Errors: $overflows',
      );
    });

    testWidgets('does not overflow at textScaler 1.3', (tester) async {
      final errors = await _captureFlutterErrors(() async {
        await tester.pumpWidget(
          _wrap(
            locale: const Locale('es'),
            textScaler: 1.3,
            home: ListingCard(listing: _listingFixture(), onTap: () {}),
          ),
        );
        await tester.pumpAndSettle();
      });
      final overflows = errors.where((e) => e.contains('RenderFlex')).toList();
      expect(
        overflows,
        isEmpty,
        reason: 'ListingCard overflowed at textScaler 1.3 — mitigation per '
            'Plan 7 Task 2: change childAspectRatio in the 4 production '
            'grids (home, all_listings, category_listings, favorites) from '
            '0.7 to 0.62. Errors: $overflows',
      );
    });
  });
}