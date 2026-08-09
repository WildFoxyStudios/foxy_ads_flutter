// Widget tests for the `/edit-profile` screen (Sprint 12 Task 4, extended in
// P10 C3 with a country selector, real avatar upload, and a read-only email
// field).
//
// `EditProfileScreen` reads `currentUserProvider` once in `initState` (via
// `ref.read(...).whenData(...)`) to pre-fill the name/phone/email controllers
// and the avatar/country state — it never `ref.watch`es it, so the pre-fill
// only happens if the provider is already resolved (`AsyncData`) on the very
// first build. In production this holds because the parent Profile screen
// already watched `currentUserProvider` before the user navigated here, so
// it's warm. To reproduce that here, the test awaits
// `container.read(currentUserProvider.future)` *before* `pumpWidget` so the
// override is already `AsyncData` by the time `initState` runs (mirrors
// `payment_success_screen_test.dart`'s approach of driving the container to
// the state the screen expects).
//
// Saving calls `AuthService.updateUserProfile` via `authServiceProvider` —
// overridden with a fake subclass (same pattern as
// `panel_gate_test.dart`'s `_StubAuthService` / `promote_listing_screen_test
// .dart`'s `FakePaymentsService`) so no Supabase round-trip happens. A
// successful save also calls `context.pop()`, so that test alone needs a
// real `GoRouter` (two routes, so there's something to pop back to) — the
// validation-failure test returns before reaching `pop()` so it's safe with
// a plain `MaterialApp`.
//
// The avatar picker calls `ImagePicker().pickImage(...)`, which hits a
// platform channel that isn't wired up in the widget-test harness (it would
// throw `MissingPluginException` if actually invoked). These tests never tap
// the avatar — they only assert structurally that the camera icon now sits
// under a `GestureDetector` with a non-null `onTap` (i.e. it's wired, not
// decorative), per the task's guidance that driving the real pick+upload
// flow is out of scope for a widget test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/core/models/user_model.dart';
import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

AppUser _userFixture() {
  return AppUser(
    id: 'u1',
    email: 'javier@example.com',
    name: 'Javier',
    phone: '+34 600 000 000',
    countryCode: 'ES',
    createdAt: DateTime(2026, 1, 1),
  );
}

SupabaseClient _dummySupabase() => SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

/// Records `updateUserProfile` calls and, when [error] is set, throws
/// instead of succeeding — matching the try/catch branches in
/// `_EditProfileScreenState._saveProfile`.
class FakeAuthService extends AuthService {
  FakeAuthService(super.supabase, {this.error});

  final Object? error;
  final List<
      ({String name, String? phone, String? avatarUrl, String? countryCode})>
      calls = [];

  @override
  Future<void> updateUserProfile({
    String? name,
    String? phone,
    String? avatarUrl,
    String? countryCode,
  }) async {
    if (error != null) throw error!;
    calls.add((
      name: name ?? '',
      phone: phone,
      avatarUrl: avatarUrl,
      countryCode: countryCode,
    ));
  }
}

void main() {
  testWidgets(
    'pre-fills the name, phone, email and country fields from currentUserProvider',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _userFixture()),
          authServiceProvider.overrideWithValue(
            FakeAuthService(_dummySupabase()),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Warm the provider so `ref.read` in initState sees AsyncData.
      await container.read(currentUserProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Javier'), findsOneWidget);
      expect(find.text('+34 600 000 000'), findsOneWidget);
      expect(find.text('javier@example.com'), findsOneWidget);
      // countryCode 'ES' resolves to España in Country.defaultCountries.
      expect(find.text('España'), findsOneWidget);
      expect(find.text('Editar Perfil'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the email as a disabled field and the country field, and the '
    'avatar area is wired to a tap handler instead of being decorative',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _userFixture()),
          authServiceProvider.overrideWithValue(
            FakeAuthService(_dummySupabase()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Email field renders and is disabled (read-only).
      final emailFieldFinder = find.ancestor(
        of: find.text('javier@example.com'),
        matching: find.byType(TextFormField),
      );
      expect(emailFieldFinder, findsOneWidget);
      final emailField = tester.widget<TextFormField>(emailFieldFinder);
      expect(emailField.enabled, isFalse);
      expect(find.text('Correo electrónico'), findsOneWidget);

      // Country field renders with its label and the pre-selected value.
      expect(find.text('País'), findsOneWidget);
      expect(find.text('España'), findsOneWidget);

      // Avatar's camera badge is no longer a dead decoration — it now sits
      // under a GestureDetector with a real onTap handler.
      final cameraIcon = find.byIcon(Icons.camera_alt);
      expect(cameraIcon, findsOneWidget);
      final avatarDetectorFinder = find.ancestor(
        of: cameraIcon,
        matching: find.byType(GestureDetector),
      );
      expect(avatarDetectorFinder, findsOneWidget);
      final avatarDetector =
          tester.widget<GestureDetector>(avatarDetectorFinder);
      expect(avatarDetector.onTap, isNotNull);
    },
  );

  testWidgets(
    'submitting with an empty name shows the validation error and does not save',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _userFixture()),
          authServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Javier'), '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(fake.calls, isEmpty);
    },
  );

  testWidgets(
    'submitting a valid form calls updateUserProfile with trimmed values, '
    'the pre-filled countryCode, and pops',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _userFixture()),
          authServiceProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserProvider.future);

      final router = GoRouter(
        initialLocation: '/root',
        routes: [
          GoRoute(
            path: '/root',
            builder: (c, s) => const Scaffold(body: SizedBox()),
          ),
          GoRoute(
            path: '/edit-profile',
            builder: (c, s) => const EditProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      router.push('/edit-profile');
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Javier'),
        '  Javier Nuevo  ',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Cambios'));
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.name, 'Javier Nuevo');
      expect(fake.calls.single.phone, '+34 600 000 000');
      // The country wasn't touched in this test, so the pre-filled value
      // (resolved from the fixture's countryCode) flows straight through.
      expect(fake.calls.single.countryCode, 'ES');
      // No avatar was picked in this test, so no URL is sent.
      expect(fake.calls.single.avatarUrl, isNull);
      // Popped back to the root route.
      expect(find.byType(EditProfileScreen), findsNothing);
    },
  );
}
