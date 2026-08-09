// Tests for first-launch IP-based country geo-detection (Sprint 13, Task
// F3), mirroring the web's `detectCountryByIP()` in
// `foxy_ads_web/src/context/CountryContext.tsx` (~L87-114).
//
// Two layers are covered:
//   1. `GeoCountryService.detectCountryCode()` — the raw HTTP call to
//      `https://ipapi.co/country/`, stubbed via `package:http/testing.dart`'s
//      `MockClient` (same pattern as `test/chat_service_test.dart`). Must
//      return the ISO code on success and `null` on ANY failure (non-200,
//      malformed body, or a thrown network error) — never throw.
//   2. `SelectedCountryNotifier`'s first-launch guard, exercised end-to-end
//      with a real `SharedPreferences` mock (`setMockInitialValues`, same
//      pattern as `test/locale_provider_test.dart`'s async-load test) and a
//      fake `GeoCountryService` override:
//        - No saved country + supported detected code -> switches AND
//          persists.
//        - No saved country + unsupported/null detected code -> stays on
//          the ES default.
//        - A country already saved -> geo-detection is never even invoked
//          (the user's explicit choice can't be overridden).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/country_model.dart';
import 'package:foxy_ads/core/services/country_service.dart';
import 'package:foxy_ads/core/services/geo_country_service.dart';

/// `CountryService` test double so the "already saved" notifier test never
/// touches a real Supabase client. Always reports the DB lookup as a miss so
/// the notifier falls back to `Country.defaultCountries` (exercising the
/// same fallback path the real service takes when offline).
class _MissingFromDbCountryService extends CountryService {
  _MissingFromDbCountryService()
      : super(
          SupabaseClient(
            'https://example.supabase.co',
            'public-anon-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<Country?> getCountryByCodeFromDatabase(String code) async => null;
}

/// Records whether `detectCountryCode()` was called and returns a
/// preconfigured result. Lets the "already saved" test assert geo-detection
/// is never invoked once a country choice exists.
class _FakeGeoCountryService extends GeoCountryService {
  _FakeGeoCountryService(this._result);
  final String? _result;
  int callCount = 0;

  @override
  Future<String?> detectCountryCode() async {
    callCount++;
    return _result;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GeoCountryService.detectCountryCode', () {
    test('returns the ISO code from a 200 plain-text response', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response('MX', 200);
      });

      final result = await GeoCountryService(client).detectCountryCode();

      expect(result, 'MX');
      expect(captured, isNotNull);
      expect(captured!.method, 'GET');
      expect(captured!.url, Uri.parse('https://ipapi.co/country/'));
    });

    test('lower-cases and trims are normalized to upper-case', () async {
      final client = MockClient((request) async => http.Response('  mx\n', 200));
      final result = await GeoCountryService(client).detectCountryCode();
      expect(result, 'MX');
    });

    test('returns null on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final result = await GeoCountryService(client).detectCountryCode();
      expect(result, isNull);
    });

    test('returns null on a malformed body instead of a 2-letter code', () async {
      final client =
          MockClient((request) async => http.Response('Undefined', 200));
      final result = await GeoCountryService(client).detectCountryCode();
      expect(result, isNull);
    });

    test('returns null (never throws) when the client throws', () async {
      final client = MockClient((request) async {
        throw Exception('network down');
      });

      // Must resolve, not throw.
      final result = await GeoCountryService(client).detectCountryCode();
      expect(result, isNull);
    });

    test('returns null (never throws) on timeout', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 10));
        return http.Response('MX', 200);
      });

      final result = await GeoCountryService(client).detectCountryCode();
      expect(result, isNull);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('SelectedCountryNotifier first-launch geo-detect guard', () {
    test(
      'first launch + supported detected code switches country and persists',
      () async {
        final geo = _FakeGeoCountryService('MX');
        final container = ProviderContainer(
          overrides: [
            geoCountryServiceProvider.overrideWithValue(geo),
          ],
        );
        addTearDown(container.dispose);

        // Trigger build(), then let the fire-and-forget async load finish.
        container.read(selectedCountryProvider);
        await pumpEventQueue();

        expect(container.read(selectedCountryProvider).code, 'MX');
        expect(geo.callCount, 1);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('selected_country_code'), 'MX');
      },
    );

    test(
      'first launch + unsupported detected code keeps the ES default',
      () async {
        final geo = _FakeGeoCountryService('ZZ'); // not in defaultCountries
        final container = ProviderContainer(
          overrides: [
            geoCountryServiceProvider.overrideWithValue(geo),
          ],
        );
        addTearDown(container.dispose);

        container.read(selectedCountryProvider);
        await pumpEventQueue();

        expect(container.read(selectedCountryProvider).code, 'ES');
        expect(geo.callCount, 1);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('selected_country_code'), isNull);
      },
    );

    test(
      'first launch + failed detection (null) keeps the ES default',
      () async {
        final geo = _FakeGeoCountryService(null);
        final container = ProviderContainer(
          overrides: [
            geoCountryServiceProvider.overrideWithValue(geo),
          ],
        );
        addTearDown(container.dispose);

        container.read(selectedCountryProvider);
        await pumpEventQueue();

        expect(container.read(selectedCountryProvider).code, 'ES');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('selected_country_code'), isNull);
      },
    );

    test(
      'a previously saved country is never overridden by geo-detection',
      () async {
        SharedPreferences.setMockInitialValues({
          'selected_country_code': 'MX',
        });
        final geo = _FakeGeoCountryService('AR');
        final container = ProviderContainer(
          overrides: [
            geoCountryServiceProvider.overrideWithValue(geo),
            countryServiceProvider.overrideWithValue(
              _MissingFromDbCountryService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(selectedCountryProvider);
        await pumpEventQueue();

        expect(container.read(selectedCountryProvider).code, 'MX');
        // Geo-detection must not even run once a country choice exists.
        expect(geo.callCount, 0);
      },
    );
  });
}
