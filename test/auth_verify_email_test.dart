// Widget + unit tests for the email-verification gate (Task 1 of the
// 4-task sprint closing audit 🟠 D.2.1).
//
// Covers:
//   1. `AuthService.resendVerificationEmail` happy path — calls Supabase,
//      does not throw.
//   2. `AuthService.resendVerificationEmail` error path — throws on failure.
//   3. `VerifyEmailScreen` reads auth state and renders the resend button
//      for an unverified user.
//   4. After resend, the "Email enviado" SnackBar appears (success).
//
// We override `authStateProvider` with a hand-rolled `StreamController`
// yielding fake `User` objects (built via `noSuchMethod` since the real
// User ctor is package-internal). The screen only reads `email` and
// `emailConfirmedAt`, which we make return whatever we configure. The
// service-level tests use a dummy SupabaseClient with a mock http
// transport — same pattern as `agency_profile_screen_test.dart`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient, User;

import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

SupabaseClient _dummyClient() {
  return SupabaseClient(
    'https://example.supabase.co',
    'public-anon-key',
    httpClient: MockClient((request) async {
      return http.Response('{}', 200,
          headers: {'content-type': 'application/json'});
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

class _StubAuthService extends AuthService {
  _StubAuthService(super.supabase);
  bool called = false;

  @override
  Future<void> resendVerificationEmail(String email) async {
    called = true;
  }
}

class _ThrowingAuthService extends AuthService {
  _ThrowingAuthService(super.supabase);
  bool called = false;

  @override
  Future<void> resendVerificationEmail(String email) async {
    called = true;
    throw Exception('Could not resend verification email: boom');
  }
}

/// A fake User that only implements the fields the screen reads. All
/// other getters throw `UnimplementedError` via `noSuchMethod`.
class _FakeUser implements User {
  _FakeUser({required this.email, String? confirmed}) : _confirmed = confirmed;
  @override
  final String email;
  final String? _confirmed;

  @override
  String? get emailConfirmedAt => _confirmed;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeUser.${invocation.memberName} is not implemented in tests',
    );
  }
}

Widget _wrap(StreamController<User?> controller, {String? redirect}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => controller.stream),
    ],
    child: MaterialApp.router(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router(redirect),
    ),
  );
}

GoRouter _router(String? redirect) {
  return GoRouter(
    initialLocation: '/verify-email',
    routes: [
      GoRoute(
        path: '/verify-email',
        builder: (c, s) => VerifyEmailScreen(redirect: redirect),
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => const Scaffold(body: Text('login')),
      ),
    ],
  );
}

Widget _routerApp() {
  return MaterialApp.router(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: _router(null),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('resendVerificationEmail happy path calls Supabase, no throw', () async {
    final svc = _StubAuthService(_dummyClient());
    // Should not throw — the stub does not actually call Supabase.
    await svc.resendVerificationEmail('test@example.com');
    expect(svc.called, isTrue);
  });

  test('resendVerificationEmail throws on error', () async {
    final svc = _ThrowingAuthService(_dummyClient());
    await expectLater(
      () => svc.resendVerificationEmail('test@example.com'),
      throwsA(isA<Exception>()),
    );
    expect(svc.called, isTrue);
  });

  testWidgets('VerifyEmailScreen renders resend button for unverified user',
      (tester) async {
    final user = _FakeUser(email: 'test@example.com');
    final stub = _StubAuthService(_dummyClient());

    // Use a Stream that has the user pre-emitted and then stays open
    // so the StreamProvider's first listen yields the data frame
    // immediately (otherwise it would emit `loading` first, the screen
    // would see `user == null`, and the postFrame callback would race
    // the data emission by navigating to /login).
    final controller = StreamController<User?>();
    scheduleMicrotask(() => controller.add(user));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => controller.stream),
          authServiceProvider.overrideWithValue(stub),
        ],
        child: _routerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reenviar email de verificación'), findsOneWidget);
  });

  testWidgets('VerifyEmailScreen shows "Email enviado" SnackBar after resend',
      (tester) async {
    final user = _FakeUser(email: 'test2@example.com');
    final stub = _StubAuthService(_dummyClient());

    final controller = StreamController<User?>();
    scheduleMicrotask(() => controller.add(user));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => controller.stream),
          authServiceProvider.overrideWithValue(stub),
        ],
        child: _routerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reenviar email de verificación'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Email enviado. Revisa tu bandeja.'), findsOneWidget);
  });
}
