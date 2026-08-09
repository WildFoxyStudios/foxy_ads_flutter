// Tests for the bulk "Destacar" (feature) action on the agency Pro
// Dashboard's `BulkListingsPanel` (mirrors the web's "Destacar en bloque").
//
// Two layers:
//   1. `PaymentsService.createBulkCheckout` — a thin unit test over the HTTP
//      transport (same `_fakes.dart` pattern as `payments_service_test.dart`
//      for the single-listing `createCheckout`): asserts the POST body
//      shape and that failures return `null` instead of throwing.
//   2. `BulkListingsPanel` widget tests — the "Destacar" toolbar button only
//      appears once 1+ listings are selected; tapping it opens the
//      duration-tier dialog showing all 5 tiers and the TOTAL (unit price x
//      selected count); confirming a tier calls
//      `createBulkCheckout(listingIds, days)`, launches the returned URL
//      (via the `url_launcher_platform_interface` test seam, same as
//      `promote_listing_screen_test.dart`), and clears the selection.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:foxy_ads/core/models/listing_model.dart';
import 'package:foxy_ads/core/utils/format_utils.dart';
import 'package:foxy_ads/features/agency/data/agency_service.dart';
import 'package:foxy_ads/features/agency/presentation/widgets/bulk_listings_panel.dart';
import 'package:foxy_ads/features/payments/data/payments_providers.dart';
import 'package:foxy_ads/features/payments/data/payments_service.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

import '_fakes.dart';

void main() {
  group('PaymentsService.createBulkCheckout', () {
    test(
      'POSTs to /functions/v1/payments-create-bulk-checkout with '
      'listingIds+days and returns the checkout url',
      () async {
        final captured = <http.Request>[];
        final supabase = makeSupabaseWithhttp((req) async {
          captured.add(req);
          return http.Response(
            jsonEncode({
              'url': 'https://checkout.stripe.com/c/pay/cs_test_bulk',
              'sessionId': 'cs_test_bulk',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final url = await svc.createBulkCheckout(
          listingIds: ['l1', 'l2'],
          days: 7,
        );

        expect(url, 'https://checkout.stripe.com/c/pay/cs_test_bulk');

        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          '/functions/v1/payments-create-bulk-checkout',
        );
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body, {
          'listingIds': ['l1', 'l2'],
          'days': 7,
        });
      },
    );

    test(
      'returns null (does not throw) on a non-2xx response',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return http.Response(
            jsonEncode({'error': 'Forbidden'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final url = await svc.createBulkCheckout(
          listingIds: ['l1'],
          days: 3,
        );

        expect(url, isNull);
      },
    );

    test(
      'returns null when the body is missing "url"',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return http.Response(
            jsonEncode({'sessionId': 'cs_test_bulk'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final url = await svc.createBulkCheckout(
          listingIds: ['l1'],
          days: 3,
        );

        expect(url, isNull);
      },
    );
  });

  group('BulkListingsPanel — bulk "Destacar"', () {
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
      'the "Destacar" toolbar button is absent with no selection and '
      'appears once a listing is checked; tapping it opens the tier dialog '
      'showing all 5 durations and the total for 1 listing',
      (tester) async {
        _useTallViewport(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('es'));
        final fakePayments = FakePaymentsService();

        await tester.pumpWidget(_buildTestApp(
          listings: [_listing('l1', 'Piso en Madrid centro')],
          payments: fakePayments,
        ));
        await tester.pumpAndSettle();

        // No selection yet -> no bulk toolbar at all.
        expect(find.text(l10n.bulkFeatureButton), findsNothing);

        // Select the single listing row (checkbox index 0 is "select all").
        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();

        final destacarButton = find.text(l10n.bulkFeatureButton);
        expect(destacarButton, findsOneWidget);

        await tester.tap(destacarButton);
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureDialogTitle(1)),
          ),
          findsOneWidget,
        );

        // All 5 duration tiers are listed with their per-listing price.
        for (final entry in featurePricesEuros.entries) {
          expect(
            find.descendant(
              of: dialog,
              matching: find.text(l10n.paymentsDaysCount(entry.key)),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: dialog,
              matching:
                  find.text(formatPrice(entry.value, 'EUR', 'es')),
            ),
            findsWidgets,
          );
        }

        // Default selection is 3 days -> total for 1 listing = unit price.
        final defaultTotal = formatPrice(
          featurePricesEuros[3]!,
          'EUR',
          'es',
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureTotal(defaultTotal)),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the total scales with the number of selected listings (2 listings, '
      'default 3-day tier = unit price x 2)',
      (tester) async {
        _useTallViewport(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('es'));
        final fakePayments = FakePaymentsService();

        await tester.pumpWidget(_buildTestApp(
          listings: [
            _listing('l1', 'Piso en Madrid centro'),
            _listing('l2', 'Ático con terraza'),
          ],
          payments: fakePayments,
        ));
        await tester.pumpAndSettle();

        // Select both listing rows (checkbox 0 is "select all").
        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox).at(2));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.bulkFeatureButton));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureDialogTitle(2)),
          ),
          findsOneWidget,
        );

        final expectedTotal = formatPrice(
          featurePricesEuros[3]! * 2,
          'EUR',
          'es',
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureTotal(expectedTotal)),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'confirming a tier calls createBulkCheckout(ids, days), launches the '
      'returned url, and clears the selection',
      (tester) async {
        _useTallViewport(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('es'));
        final fakePayments = FakePaymentsService(
          url: 'https://checkout.stripe.com/c/pay/cs_test_bulk_flow',
        );

        await tester.pumpWidget(_buildTestApp(
          listings: [_listing('l1', 'Piso en Madrid centro')],
          payments: fakePayments,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.bulkFeatureButton));
        await tester.pumpAndSettle();

        // Switch the tier to 7 days, then confirm.
        await tester.tap(find.text(l10n.paymentsDaysCount(7)));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureButton),
          ),
        );
        await tester.pumpAndSettle();

        expect(fakePayments.calls, hasLength(1));
        expect(fakePayments.calls.single.listingIds, ['l1']);
        expect(fakePayments.calls.single.days, 7);

        expect(fakeLauncher.launchedUrls, [
          'https://checkout.stripe.com/c/pay/cs_test_bulk_flow',
        ]);

        // Selection was cleared -> the bulk toolbar is gone again.
        expect(find.text(l10n.bulkFeatureButton), findsNothing);
      },
    );

    testWidgets(
      'shows an error SnackBar and keeps the selection when '
      'createBulkCheckout fails (returns null)',
      (tester) async {
        _useTallViewport(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('es'));
        final fakePayments = FakePaymentsService(returnsNull: true);

        await tester.pumpWidget(_buildTestApp(
          listings: [_listing('l1', 'Piso en Madrid centro')],
          payments: fakePayments,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.bulkFeatureButton));
        await tester.pumpAndSettle();

        final dialog = find.byType(AlertDialog);
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.bulkFeatureButton),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.bulkFeatureFailed), findsOneWidget);
        expect(fakeLauncher.launchedUrls, isEmpty);
        // Selection preserved so the user can retry.
        expect(find.text(l10n.bulkFeatureButton), findsOneWidget);
      },
    );
  });
}

/// Records `(listingIds, days)` calls and returns either the canned [url]
/// or `null` (when [returnsNull] is set) — mirrors `FakePaymentsService` in
/// `promote_listing_screen_test.dart` but for the bulk edge function.
class FakePaymentsService extends PaymentsService {
  FakePaymentsService({
    this.url = 'https://checkout.stripe.com/c/pay/cs_test_abc',
    this.returnsNull = false,
  }) : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final String url;
  final bool returnsNull;

  final List<({List<String> listingIds, int days})> calls = [];

  @override
  Future<String?> createBulkCheckout({
    required List<String> listingIds,
    required int days,
  }) async {
    calls.add((listingIds: listingIds, days: days));
    return returnsNull ? null : url;
  }
}

/// `UrlLauncherPlatform` test fake that records `launchUrl` calls, same as
/// `promote_listing_screen_test.dart`'s.
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

Widget _buildTestApp({
  required List<Listing> listings,
  required FakePaymentsService payments,
}) {
  return ProviderScope(
    overrides: [
      myPanelListingsProvider.overrideWith((ref) async => listings),
      paymentsServiceProvider.overrideWithValue(payments),
    ],
    child: const MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: BulkListingsPanel()),
    ),
  );
}

/// Bumps the test viewport tall enough to hold the panel + toolbar + rows
/// without a `RenderFlex overflowed` warning (mirrors `leads_panel_test.dart`).
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
