// Widget tests for the `/register` screen (Sprint 12 Task 4).
//
// `RegisterScreen` is a `ConsumerStatefulWidget` with no provider reads on
// build — all four text fields start empty and validation runs entirely
// through `Form`/`TextFormField` validators, so no provider warm-up is
// needed (unlike `edit_profile_screen_test.dart`).
//
// `_signUp()` calls `AuthService.signUpWithEmail` via `authServiceProvider`
// — overridden with a fake subclass (same pattern as `panel_gate_test.dart`'s
// `_StubAuthService`) so no Supabase round-trip happens — and on success
// calls `context.go('/')`, so the happy-path test needs a real `GoRouter`
// with both `/register` and `/` registered. The validation-only tests never
// reach that call (they return early), so they run fine even with the same
// router wired up (kept as one shared `_buildTestApp` helper for
// consistency across the four tests).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthResponse, SupabaseClient;

import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/auth/presentation/screens/register_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

SupabaseClient _dummySupabase() => SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

/// Records `signUpWithEmail` calls (or throws, when [error] is set) without
/// touching Supabase. `signInWithGoogle` is left inherited (unused by these
/// tests — would hit the native Google Sign-In plugin if ever called).
class FakeAuthService extends AuthService {
  FakeAuthService(super.supabase, {this.error});

  final Object? error;
  final List<({String email, String password, String? name})> calls = [];

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    if (error != null) throw error!;
    calls.add((email: email, password: password, name: name));
    return AuthResponse();
  }
}

Widget _buildTestApp(GoRouter router, FakeAuthService authService) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(authService)],
    child: MaterialApp.router(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/register',
        builder: (c, s) => const RegisterScreen(),
      ),
    ],
  );
}

/// Fills all four fields with valid values. Does NOT touch the terms
/// checkbox — callers opt in separately.
Future<void> _fillValidFields(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Javier Test');
  await tester.enterText(fields.at(1), 'javier@example.com');
  await tester.enterText(fields.at(2), 'secret123');
  await tester.enterText(fields.at(3), 'secret123');
}

/// The "Crear Cuenta" CTA sits below the fold of the screen's
/// `SingleChildScrollView` — scroll it into view before tapping (same
/// approach as `promote_listing_screen_test.dart`'s `cta` tap).
Future<void> _tapCreateAccount(WidgetTester tester) async {
  final cta = find.widgetWithText(ElevatedButton, 'Crear Cuenta');
  await tester.scrollUntilVisible(cta, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(cta);
}

void main() {
  testWidgets(
    'renders the name, email, password, confirm-password fields and CTA',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      await tester.pumpWidget(_buildTestApp(_buildRouter(), fake));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Crear Cuenta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submitting an empty form shows validation errors and does not sign up',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      await tester.pumpWidget(_buildTestApp(_buildRouter(), fake));
      await tester.pumpAndSettle();

      await _tapCreateAccount(tester);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa una contraseña'), findsOneWidget);
      expect(fake.calls, isEmpty);
    },
  );

  testWidgets(
    'valid fields but unchecked terms shows the accept-terms snackbar and does not sign up',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      await tester.pumpWidget(_buildTestApp(_buildRouter(), fake));
      await tester.pumpAndSettle();

      await _fillValidFields(tester);
      await _tapCreateAccount(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Debes aceptar los términos y condiciones'),
        findsOneWidget,
      );
      expect(fake.calls, isEmpty);
    },
  );

  testWidgets(
    'valid fields + accepted terms calls signUpWithEmail with trimmed values and navigates home',
    (tester) async {
      final fake = FakeAuthService(_dummySupabase());
      await tester.pumpWidget(_buildTestApp(_buildRouter(), fake));
      await tester.pumpAndSettle();

      await _fillValidFields(tester);
      await tester.tap(find.byType(Checkbox));
      await _tapCreateAccount(tester);
      await tester.pumpAndSettle();

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.email, 'javier@example.com');
      expect(fake.calls.single.password, 'secret123');
      expect(fake.calls.single.name, 'Javier Test');
      // Navigated to '/' — the register screen is gone, the home
      // placeholder route is showing.
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
  );
}
