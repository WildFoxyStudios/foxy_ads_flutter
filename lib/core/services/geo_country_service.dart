// First-launch IP-based country detection — mirrors the web's
// `detectCountryByIP()` in `foxy_ads_web/src/context/CountryContext.tsx`
// (~lines 87-114), which calls `https://ipapi.co/json/`. Here we use
// `https://ipapi.co/country/`, the plain-text variant of the same endpoint —
// it returns just the ISO-3166-1 alpha-2 code (e.g. `"MX"`) as the response
// body, so there's no JSON to parse.
//
// This is a *defensive* best-effort lookup: any failure (network error,
// timeout, non-200, malformed body) must resolve to `null`, never throw.
// Callers decide what to do with `null` (keep the current default).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final geoCountryServiceProvider = Provider<GeoCountryService>((ref) {
  return GeoCountryService();
});

class GeoCountryService {
  GeoCountryService([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://ipapi.co/country/');

  /// Returns the caller's ISO-3166-1 alpha-2 country code as detected from
  /// their IP address, or `null` if detection fails for any reason
  /// (network error, timeout, non-200 response, or an unparseable body).
  ///
  /// Never throws.
  Future<String?> detectCountryCode() async {
    try {
      final response = await _client
          .get(_endpoint)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final code = response.body.trim().toUpperCase();
      // A valid ISO-3166-1 alpha-2 code is exactly two letters. ipapi.co
      // returns things like "Undefined" or an empty body on lookup failure
      // (e.g. private/reserved IP ranges) — reject anything that isn't
      // exactly two letters rather than trying to enumerate every failure
      // string it might send.
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;

      return code;
    } catch (_) {
      // Network error, timeout, or anything else — fail silently.
      return null;
    }
  }
}
