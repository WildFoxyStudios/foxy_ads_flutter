// Widget tests for the `/promote/:listingId` screen (Task 2 of the Stripe
// payments sprint).
//
// The screen is the entry point to Stripe Checkout. Tapping the primary CTA
// must:
//   * call `PaymentsService.createCheckout` with `(listingId, days)` and
//   * hand the returned `url` to `launchUrl(...)` (external app mode).
//
// It must NOT call `ListingService.promoteListing` (the old, buggy direct-
// promote path that bypassed payment). That regression assertion is the
// load-bearing part of this test.
//
// Strategy:
//   * Override `paymentsServiceProvider` with `FakePaymentsService` so the
//     service never touches Supabase and records its calls.
//   * Override `listingServiceProvider` with `SpyListingService` so the test
//     can assert `promoteListing` was NEVER called (the regression guard).
//   * Override `UrlLauncherPlatform.instance` with `FakeUrlLauncherPlatform`
//     to capture the URL that the screen would launch. This is the test
//     seam provided by `url_launcher_platform_interface` and avoids
//     touching any plugin platform channel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/providers/selected_country_provider.dart';
import 'package:foxy_ads/core/services/listing_service.dart';
import 'package:foxy_ads/features/payments/data/payments_providers.dart';
import 'package:foxy_ads/features/payments/data/payments_service.dart';
import 'package:foxy_ads/features/payments/presentation/screens/promote_listing_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

final _testCountry = Country(
  code: 'ES',
  name: 'España',
  flag: '🇪🇸',
  currency: 'EUR',
  currencySymbol: '€',
);

class _FakeCountryNotifier extends SelectedCountryNotifier {
  @override
  Country build() => _testCountry;
}

/// Records the (listingId, days) tuple handed to `createCheckout` and
/// returns the canned (url, sessionId) the test set up. Mirrors the
/// subclass-override pattern from `promociones_screen_test.dart`.
class FakePaymentsService extends PaymentsService {
  FakePaymentsService({
    this.url = 'https://checkout.stripe.com/c/pay/cs_test_abc',
    this.sessionId = 'cs_test_abc',
  }) : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final String url;
  final String sessionId;

  final List<({String listingId, int days})> calls = [];

  @override
  Future<({String url, String sessionId})> createCheckout({
    required String listingId,
    required int days,
  }) async {
    calls.add((listingId: listingId, days: days));
    return (url: url, sessionId: sessionId);
  }
}

/// Watches `promoteListing` and `getListingById` (called by the screen's
/// `promoteListingProvider`). The latter returns the canned listing so the
/// body renders; the former is the regression guard — the test asserts it
/// is NEVER invoked.
class SpyListingService extends ListingService {
  SpyListingService(this._listing)
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final Listing _listing;
  int getListingByIdCalls = 0;
  int promoteListingCalls = 0;

  @override
  Future<Listing?> getListingById(String id) async {
    getListingByIdCalls++;
    return _listing;
  }

  @override
  Future<void> promoteListing({
    required String id,
    required int days,
    required int priceCents,
  }) async {
    promoteListingCalls++;
  }
}

/// `UrlLauncherPlatform` test fake that records `launchUrl` calls. We only
/// override the two methods the screen actually calls; everything else
/// throws to make any surprise code path obvious.
class FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

Listing _listing(String id) {
  return Listing(
    id: id,
    userId: 'owner-1',
    categoryId: 'cat-1',
    countryCode: 'ES',
    title: 'iPhone 13 Pro',
    description: 'Test listing',
    price: 500,
    currency: 'EUR',
    images: const <String>[],
    city: 'Madrid',
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _buildTestApp({
  required FakePaymentsService payments,
  required SpyListingService listings,
}) {
  return ProviderScope(
    overrides: [
      selectedCountryProvider.overrideWith(() => _FakeCountryNotifier()),
      paymentsServiceProvider.overrideWithValue(payments),
      listingServiceProvider.overrideWithValue(listings),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PromoteListingScreen(listingId: 'list-1'),
    ),
  );
}

void main() {
  group('PromoteListingScreen Stripe Checkout redirect', () {
    late FakeUrlLauncherPlatform fakeLauncher;
    late UrlLauncherPlatform originalLauncher;

    setUp(() {
      fakeLauncher = FakeUrlLauncherPlatform();
      originalLauncher = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = fakeLauncher;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalLauncher;
    });

    testWidgets(
      'tapping Continue calls createCheckout(listingId, days) and launchUrl(url); '
      'never calls promoteListing (regression guard)',
      (tester) async {
        final payments = FakePaymentsService();
        final listings = SpyListingService(_listing('list-1'));

        await tester.pumpWidget(_buildTestApp(
          payments: payments,
          listings: listings,
        ));
        await tester.pumpAndSettle();

        // The CTA is the primary ElevatedButton on the screen. It's below
        // the fold of a SingleChildScrollView, so scroll it into view before
        // tapping.
        final cta = find.widgetWithText(ElevatedButton, 'Continuar a Stripe');
        expect(cta, findsOneWidget,
            reason: 'Expected the new "Continuar a Stripe" CTA to be present');
        await tester.scrollUntilVisible(cta, 200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(cta);
        await tester.pumpAndSettle();

        // The checkout service was called with the right args.
        expect(payments.calls, hasLength(1));
        expect(payments.calls.single.listingId, 'list-1');
        expect(payments.calls.single.days, 3,
            reason: 'Default selected duration is 3 days');

        // The redirect URL was handed to launchUrl.
        expect(fakeLauncher.launchedUrls, [
          'https://checkout.stripe.com/c/pay/cs_test_abc',
        ]);

        // Regression: the screen must NOT call promoteListing directly.
        // That was the original bug — promoting without taking the user's
        // money. The Stripe webhook is the only path that should flip
        // `is_featured` server-side.
        expect(listings.promoteListingCalls, 0,
            reason: 'promoteListing must not be called by the screen');
      },
    );
  });
}
