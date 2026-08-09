// Unit + widget tests for the preferred-currency selector (P10 C5).
//
// `users.preferred_currency` is a Phase-5 column that is NOT guaranteed to
// exist in production yet (see [[restructuring-phases]] / [[admin-prod-hotfixes]]
// in project memory). The web mirrors this by isolating the read from the
// main profile SELECT and swallowing any error; `AuthService.getPreferredCurrency`
// / `setPreferredCurrency` do the same on the Flutter side (see
// lib/core/services/auth_service.dart). These tests verify:
//   1. `isColumnAbsentError` — the pure predicate used to recognize a
//      "column does not exist" PostgrestException (diagnostic only; it does
//      NOT change the read/write's own broad catch-all behavior).
//   2. `AuthService.getPreferredCurrency` / `setPreferredCurrency` against a
//      fake Supabase backed by `http.MockClient` (same pattern as
//      `payments_service_test.dart`): a simulated "column does not exist"
//      response (400, code 42703) never throws — it resolves to null/false.
//      Also covers an unrelated 500 error, to prove the catch is broad, not
//      just column-absent-specific.
//   3. A widget test that the Settings screen's currency tile renders (with
//      a country-derived fallback when the read returns null) and that
//      opening the picker shows a list of currencies.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, PostgrestException, SupabaseClient, User;

import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/settings/presentation/screens/settings_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

import '_fakes.dart';

User _stubUser() {
  return User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'javier@example.com',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );
}

/// A 400 PostgREST error body shaped like a real "column does not exist"
/// response (undefined_column, Postgres code 42703).
///
/// [request] must be threaded through: `postgrest`'s response parser reads
/// `response.request!.method`, and `http.testing.MockClient` only populates
/// `Response.request` if the handler explicitly sets it (it does not attach
/// it automatically the way a real HTTP round-trip would).
http.Response _columnAbsentResponse(http.Request request) => http.Response(
      jsonEncode({
        'code': '42703',
        'details': null,
        'hint': null,
        'message': 'column users.preferred_currency does not exist',
      }),
      400,
      request: request,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('isColumnAbsentError', () {
    test('true for PGRST204 (PostgREST schema-cache miss)', () {
      const e = PostgrestException(
        message: "Could not find the 'preferred_currency' column",
        code: 'PGRST204',
      );
      expect(isColumnAbsentError(e), isTrue);
    });

    test('true for 42703 (Postgres undefined_column)', () {
      const e = PostgrestException(
        message: 'column users.preferred_currency does not exist',
        code: '42703',
      );
      expect(isColumnAbsentError(e), isTrue);
    });

    test(
      'true when the message names the missing column even under an '
      'unrelated code',
      () {
        const e = PostgrestException(
          message:
              'Could not find the preferred_currency column of users in '
              'the schema cache',
          code: 'PGRST000',
        );
        expect(isColumnAbsentError(e), isTrue);
      },
    );

    test('false for an unrelated PostgrestException (e.g. permission denied)', () {
      const e = PostgrestException(message: 'permission denied', code: '42501');
      expect(isColumnAbsentError(e), isFalse);
    });

    test('false for a non-PostgrestException error, and never throws', () {
      expect(isColumnAbsentError(Exception('boom')), isFalse);
      expect(isColumnAbsentError('a plain string'), isFalse);
      expect(isColumnAbsentError(StateError('bad state')), isFalse);
    });
  });

  group('AuthService.getPreferredCurrency', () {
    test('returns the value when the column exists', () async {
      final supabase = makeSupabaseWithhttp((req) async {
        return http.Response(
          jsonEncode({'preferred_currency': 'EUR'}),
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = AuthService(supabase);

      final result = await service.getPreferredCurrency('u1');

      expect(result, 'EUR');
    });

    test(
      'returns null (never throws) when the column does not exist',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return _columnAbsentResponse(req);
        });
        final service = AuthService(supabase);

        // The important assertion: no exception propagates out of the
        // service, regardless of what PostgREST returns.
        final result = await service.getPreferredCurrency('u1');

        expect(result, isNull);
      },
    );

    test(
      'returns null on an unrelated server error too (the catch is broad, '
      'not just column-absent-specific)',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return http.Response('Internal Server Error', 500, request: req);
        });
        final service = AuthService(supabase);

        final result = await service.getPreferredCurrency('u1');

        expect(result, isNull);
      },
    );
  });

  group('AuthService.setPreferredCurrency', () {
    test('returns true on a successful update', () async {
      final supabase = makeSupabaseWithhttp((req) async {
        // PATCH with default Prefer: return=minimal -> 204 No Content.
        return http.Response('', 204, request: req);
      });
      final service = AuthService(supabase);

      final result = await service.setPreferredCurrency('u1', 'USD');

      expect(result, isTrue);
    });

    test(
      'returns false (never throws) when the column does not exist',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return _columnAbsentResponse(req);
        });
        final service = AuthService(supabase);

        final result = await service.setPreferredCurrency('u1', 'USD');

        expect(result, isFalse);
      },
    );

    test(
      'returns false on an unrelated server error too',
      () async {
        final supabase = makeSupabaseWithhttp((req) async {
          return http.Response('Internal Server Error', 500, request: req);
        });
        final service = AuthService(supabase);

        final result = await service.setPreferredCurrency('u1', 'USD');

        expect(result, isFalse);
      },
    );
  });

  group('SettingsScreen preferred-currency tile', () {
    testWidgets(
      'renders with the country-derived fallback when the read returns '
      'null (column absent), and opening the picker lists currencies',
      (tester) async {
        final dummySupabase = SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(_stubUser()),
            ),
            // Simulates the column-absent case end to end: the provider
            // calls into AuthService.getPreferredCurrency, which is
            // defensive by construction, so this resolves to null rather
            // than erroring the provider.
            preferredCurrencyProvider.overrideWith((ref) async => null),
            authServiceProvider.overrideWithValue(AuthService(dummySupabase)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The tile renders with a label and a non-empty subtitle even
        // though the read resolved to null — it falls back to the
        // selected country's currency (EUR by default) instead of
        // crashing or showing nothing.
        expect(find.text('Moneda preferida'), findsOneWidget);
        expect(find.textContaining('EUR'), findsWidgets);

        // Opening the picker shows a list of selectable currencies.
        await tester.tap(find.text('Moneda preferida'));
        await tester.pumpAndSettle();

        expect(find.byType(RadioListTile<String>), findsWidgets);
        // ARS sorts first alphabetically among the distinct currencies, so
        // it's guaranteed to be within the dialog's initial viewport (the
        // list isn't lazily fully materialized off-screen — later entries
        // like USD may be scrolled out of the small test surface).
        expect(find.textContaining('ARS'), findsWidgets);
      },
    );

    testWidgets(
      'shows the neutral "unavailable" snackbar (not an error) when the '
      'write fails, e.g. because the column does not exist yet',
      (tester) async {
        final dummySupabase = SupabaseClient(
          'https://example.supabase.co',
          'public-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(_stubUser()),
            ),
            preferredCurrencyProvider.overrideWith((ref) async => null),
            authServiceProvider.overrideWithValue(
              _AlwaysFailsAuthService(dummySupabase),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Moneda preferida'));
        await tester.pumpAndSettle();

        // Pick ARS from the list (first alphabetically, so guaranteed
        // visible without scrolling — see the previous test's comment).
        await tester.tap(find.text('ARS (\$)'));
        await tester.pumpAndSettle();

        expect(
          find.text('La moneda preferida aún no está disponible'),
          findsOneWidget,
        );
      },
    );
  });
}

/// Stands in for the un-deployed-migration scenario: `setPreferredCurrency`
/// always reports failure, mirroring what the real defensive implementation
/// returns when the column doesn't exist — without needing a fake HTTP
/// transport wired through the widget tree.
class _AlwaysFailsAuthService extends AuthService {
  _AlwaysFailsAuthService(super.supabase);

  @override
  Future<bool> setPreferredCurrency(String userId, String currency) async {
    return false;
  }
}
