// Service that proxies the two Supabase edge functions backing the Stripe
// payments flow on the client side:
//
//   * `payments-create-checkout`  — POST {listingId, days} -> {url, sessionId}
//   * `payments-resolve-session`  — GET  ?sessionId=…       -> {listingId, title}
//
// The edge function URLs are reached via `supabase.functions.invoke(...)`,
// which automatically attaches the caller's session JWT in the `Authorization`
// header (same pattern used by `auth_service.dart` -> `delete-account`).
//
// Errors:
//   * `createCheckout` throws if the edge function responds with a non-2xx
//     status or the JSON body is missing `url` / `sessionId`.
//   * `resolveSession` swallows non-2xx responses (the listing may not be
//     promoted yet — the caller can show a "pending" state).

import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentsService {
  PaymentsService(this._supabase);

  final SupabaseClient _supabase;

  /// Creates a Stripe Checkout session for the given listing + duration and
  /// returns the redirect URL and the Stripe session id.
  Future<({String url, String sessionId})> createCheckout({
    required String listingId,
    required int days,
  }) async {
    final res = await _supabase.functions.invoke(
      'payments-create-checkout',
      body: {'listingId': listingId, 'days': days},
    );
    final data = res.data is Map ? res.data as Map : <String, dynamic>{};
    if (res.status != 200 ||
        data['url'] is! String ||
        data['sessionId'] is! String) {
      throw Exception('Checkout creation failed: ${res.status}');
    }
    return (url: data['url'] as String, sessionId: data['sessionId'] as String);
  }

  /// Resolves a Stripe Checkout session to the listing it was created for.
  ///
  /// Returns `(null, null)` if the edge function responds with non-2xx (e.g.
  /// the session doesn't exist or the payment is not completed yet). The
  /// caller is expected to render a "pending" UI in that case.
  Future<({String? listingId, String? title})> resolveSession(
    String sessionId,
  ) async {
    final FunctionResponse res;
    try {
      res = await _supabase.functions.invoke(
        'payments-resolve-session',
        queryParameters: {'sessionId': sessionId},
      );
    } on Exception {
      // Non-2xx responses raise `FunctionException` from `functions_client`;
      // treat them as "no listing resolved yet" so the caller can show a
      // pending state.
      return (listingId: null, title: null);
    }
    if (res.status != 200) return (listingId: null, title: null);
    final data = res.data is Map ? res.data as Map : <String, dynamic>{};
    return (
      listingId: data['listingId'] as String?,
      title: data['title'] as String?,
    );
  }
}
