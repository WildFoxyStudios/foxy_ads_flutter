// Widget tests for the "Eliminar agencia" (delete agency profile) button on
// `/agencia/editar` (P12 F3). Mirrors the web's `deleteAgencyProfileAction`
// (`foxy_ads_web/src/app/actions/agency.ts`): a plain delete of the caller's
// `agency_profiles` row, scoped by RLS, that does NOT touch `listings`.
//
// Follows `panel_gate_test.dart`'s pattern: override `myAgencyProfileProvider`
// directly (no real Supabase round trip) and `authStateProvider` with a
// signed-in-user stream so the screen reaches the form instead of the
// "Inicia sesión" gate. `agencyServiceProvider` is overridden with a fake
// subclass (same shape as `agency_profile_screen_test.dart`'s
// `FakeAgencyService`) so `deleteAgencyProfile` calls are recorded instead of
// hitting Supabase.
//
// Covers:
//   - The button renders when editing an EXISTING profile
//     (`myAgencyProfileProvider` resolves non-null).
//   - The button is ABSENT when creating a new profile
//     (`myAgencyProfileProvider` resolves null).
//   - Tapping the button -> confirm dialog -> confirming calls
//     `AgencyService.deleteAgencyProfile` with the signed-in user's id and
//     pops back to the previous route.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient, User;

import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/agency/data/agency_model.dart';
import 'package:foxy_ads/features/agency/data/agency_service.dart';
import 'package:foxy_ads/features/agency/presentation/screens/agency_profile_edit_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

AgencyProfile _profile() {
  return const AgencyProfile(
    userId: 'agency-1',
    name: 'Fox Real Estate',
    createdAt: '2026-01-01T00:00:00.000Z',
    isVerified: true,
  );
}

User _stubUser() {
  return User(
    id: 'agency-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'agency@example.com',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );
}

/// Fake `AgencyService` that records `deleteAgencyProfile` calls instead of
/// hitting Supabase. `fetchAgencyProfile`/`upsertAgencyProfile` are never
/// exercised by these tests (the profile comes from the overridden
/// `myAgencyProfileProvider`), so only `deleteAgencyProfile` is overridden.
class FakeAgencyService extends AgencyService {
  FakeAgencyService(super.supabase);

  final List<String> deleteCalls = [];

  @override
  Future<void> deleteAgencyProfile(String userId) async {
    deleteCalls.add(userId);
  }
}

SupabaseClient _dummySupabase() => SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

void main() {
  testWidgets(
    'shows the "Eliminar agencia" button when editing an existing profile',
    (tester) async {
      // The form (logo + 5 fields + save + delete) overflows the default
      // 800x600 test viewport, and `ListView(children: ...)` only builds
      // widgets within the viewport — a tall surface avoids needing a
      // scroll-to-visible dance to find the delete button.
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAgencyProfileProvider.overrideWith(
              (ref) async => _profile(),
            ),
            authStateProvider.overrideWith(
              (ref) => Stream.value(_stubUser()),
            ),
            agencyServiceProvider.overrideWithValue(
              FakeAgencyService(_dummySupabase()),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AgencyProfileEditScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eliminar agencia'), findsOneWidget);
    },
  );

  testWidgets(
    'does NOT show the "Eliminar agencia" button when creating a new profile',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAgencyProfileProvider.overrideWith((ref) async => null),
            authStateProvider.overrideWith(
              (ref) => Stream.value(_stubUser()),
            ),
            agencyServiceProvider.overrideWithValue(
              FakeAgencyService(_dummySupabase()),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AgencyProfileEditScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eliminar agencia'), findsNothing);
    },
  );

  testWidgets(
    'tapping delete then confirming calls deleteAgencyProfile and pops back',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = FakeAgencyService(_dummySupabase());
      final router = GoRouter(
        initialLocation: '/root',
        routes: [
          GoRoute(
            path: '/root',
            builder: (c, s) => const Scaffold(body: SizedBox()),
          ),
          GoRoute(
            path: '/agencia/editar',
            builder: (c, s) => const AgencyProfileEditScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myAgencyProfileProvider.overrideWith(
              (ref) async => _profile(),
            ),
            authStateProvider.overrideWith(
              (ref) => Stream.value(_stubUser()),
            ),
            agencyServiceProvider.overrideWithValue(fake),
          ],
          child: MaterialApp.router(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      router.push('/agencia/editar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eliminar agencia'));
      await tester.pumpAndSettle();

      // Confirm dialog is shown with the confirm copy.
      expect(find.text('¿Eliminar tu agencia?'), findsOneWidget);

      // The dialog's confirm action also reads "Eliminar agencia" — tap the
      // second occurrence (the first is the now-obscured button behind the
      // dialog barrier).
      await tester.tap(find.text('Eliminar agencia').last);
      await tester.pumpAndSettle();

      expect(fake.deleteCalls, ['agency-1']);
      // Popped back to the root route.
      expect(find.byType(AgencyProfileEditScreen), findsNothing);
    },
  );
}
