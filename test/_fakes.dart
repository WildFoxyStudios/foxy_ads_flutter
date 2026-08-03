// Shared test fakes for mocking Supabase in widget/unit tests.
//
// Currently exposes [makeSupabaseWithHttp] — a helper that builds a real
// [SupabaseClient] backed by a caller-supplied `http.MockClient` so individual
// tests can stub the HTTP responses returned by the edge functions (or any
// other sub-client) without a network round-trip.
//
// Pattern adapted from the existing tests in this directory
// (e.g. `agency_profile_screen_test.dart`, `promociones_screen_test.dart`)
// which build a real `SupabaseClient` with a dummy URL/key and disable
// GoTrue's auto-refresh so the constructor doesn't leave a periodic timer
// alive across `pumpAndSettle`. Here we additionally inject a custom
// `http.Client` so the `FunctionsClient` (and any other sub-client) routes
// through the caller-supplied [MockClient].
//
// Usage:
//   final client = makeSupabaseWithHttp((request) async {
//     return http.Response('{"url":"https://...","sessionId":"cs_..."}', 200,
//         headers: {'content-type': 'application/json'});
//   });
//   final svc = PaymentsService(client);

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a [SupabaseClient] whose `http.Client` is the given [handler]
/// (typically a [MockClient] closure that returns canned responses).
///
/// GoTrue's auto-refresh is disabled so no auth-refresh timer is left alive
/// after the test (which would trip the binding's "no timers pending"
/// invariant under `pumpAndSettle`).
SupabaseClient makeSupabaseWithhttp(
  Future<http.Response> Function(http.Request request) handler,
) {
  final mock = MockClient(handler);
  return SupabaseClient(
    'https://example.supabase.co',
    'public-anon-key',
    httpClient: mock,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}
