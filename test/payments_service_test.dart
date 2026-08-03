// Unit tests for the `PaymentsService` (Task 1 of the Stripe payments sprint).
//
// `PaymentsService` is a thin wrapper over two Supabase edge functions:
//   * `payments-create-checkout`  — POST {listingId, days} -> {url, sessionId}
//   * `payments-resolve-session`  — GET ?sessionId=…        -> {listingId, title}
//
// These tests stub the HTTP transport via `test/_fakes.dart` so the real
// service code runs end-to-end (invoke → JSON parse → tuple return / throw)
// without a network round-trip.
//
// Follows the same "real SupabaseClient with a fake http.Client" pattern that
// the existing fake-Supabase tests use, with `autoRefreshToken: false` to
// avoid leaving a GoTrue timer alive.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:foxy_ads/features/payments/data/payments_service.dart';

import '_fakes.dart';

void main() {
  group('PaymentsService.createCheckout', () {
    test(
      'POSTs to /functions/v1/payments-create-checkout with listingId+days '
      'and returns (url, sessionId)',
      () async {
        final captured = <_CapturedRequest>[];
        final supabase = makeSupabaseWithhttp((req) async {
          captured.add(_CapturedRequest(
            method: req.method,
            url: req.url,
            body: req.body,
          ));
          return http.Response(
            jsonEncode({
              'url': 'https://checkout.stripe.com/c/pay/cs_test_abc',
              'sessionId': 'cs_test_abc',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final r = await svc.createCheckout(
          listingId: 'list-1',
          days: 7,
        );

        expect(r.url, 'https://checkout.stripe.com/c/pay/cs_test_abc');
        expect(r.sessionId, 'cs_test_abc');

        // Exactly one HTTP call went out, to the right function.
        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          '/functions/v1/payments-create-checkout',
        );
        // The body is the JSON payload with listingId+days.
        final body = jsonDecode(captured.single.body) as Map<String, dynamic>;
        expect(body, {'listingId': 'list-1', 'days': 7});
      },
    );

    test('throws on non-2xx response from payments-create-checkout', () async {
      final supabase = makeSupabaseWithhttp((req) async {
        return http.Response(
          jsonEncode({'error': 'Listing not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final svc = PaymentsService(supabase);
      await expectLater(
        () => svc.createCheckout(listingId: 'x', days: 7),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PaymentsService.resolveSession', () {
    test(
      'POSTs to /functions/v1/payments-resolve-session?sessionId=… and returns '
      '(listingId, title) for a paid session',
      () async {
        final captured = <_CapturedRequest>[];
        final supabase = makeSupabaseWithhttp((req) async {
          captured.add(_CapturedRequest(
            method: req.method,
            url: req.url,
            body: req.body,
          ));
          return http.Response(
            jsonEncode({
              'listingId': 'list-1',
              'title': 'Piso en Madrid centro',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final r = await svc.resolveSession('cs_test_abc');

        expect(r.listingId, 'list-1');
        expect(r.title, 'Piso en Madrid centro');

        // Exactly one HTTP call went out, to the right function with the
        // sessionId passed as a query parameter. `supabase.functions.invoke`
        // always uses POST — query params travel in the URL.
        expect(captured, hasLength(1));
        expect(captured.single.method, 'POST');
        expect(
          captured.single.url.path,
          '/functions/v1/payments-resolve-session',
        );
        expect(
          captured.single.url.queryParameters,
          {'sessionId': 'cs_test_abc'},
        );
      },
    );

    test(
      'returns (null, null) when resolve-session responds non-2xx '
      '(Stripe not paid / unknown session)',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return http.Response(
            jsonEncode({'error': 'Payment not completed', 'status': 'open'}),
            402,
            headers: {'content-type': 'application/json'},
          );
        });

        final svc = PaymentsService(supabase);
        final r = await svc.resolveSession('cs_test_unknown');

        expect(r.listingId, isNull);
        expect(r.title, isNull);
      },
    );
  });
}

/// Captures an HTTP request as seen by the fake transport.
class _CapturedRequest {
  _CapturedRequest({
    required this.method,
    required this.url,
    required this.body,
  });
  final String method;
  final Uri url;
  final String body;
}
