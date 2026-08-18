// Widget + unit tests for the email-verification gate (Task 1 of the
// 4-task sprint closing audit 🟠 D.2.1).
//
// Covers:
//   1. `AuthService.resendVerificationEmail` happy path — calls Supabase
//      with `OtpType.email` (NOT `OtpType.signup`), does not throw.
//   2. `AuthService.resendVerificationEmail` error path — throws on failure.
//   3. `VerifyEmailScreen` reads auth state and renders the resend button
//      for an unverified user.
//   4. After resend, the "Email enviado" SnackBar appears (success).
//
// The service-level tests exercise the REAL `AuthService.resendVerificationEmail`
// against a fake `GoTrueClient` that records its invocations, so the test
// catches a regression where `OtpType.signup` is used in place of
// `OtpType.email` (the bug found in Sprint-8 T1 review). The screen-level
// tests stub `authServiceProvider` so they don't need a real Supabase round-
// trip — they only assert rendering and SnackBar behavior.
//
// We override `authStateProvider` with a hand-rolled `StreamController`
// yielding fake `User` objects (built via `noSuchMethod` since the real
// User ctor is package-internal). The screen only reads `email` and
// `emailConfirmedAt`, which we make return whatever we configure.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthClientOptions,
        GoTrueClient,
        OtpType,
        ResendResponse,
        SupabaseClient,
        User;

import 'package:foxy_ads/core/services/auth_service.dart';
import 'package:foxy_ads/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Captured `auth.resend(...)` invocation. Lets the test assert that the
/// real `AuthService.resendVerificationEmail` passes the correct `type`.
class _CapturedResend {
  _CapturedResend({required this.email, required this.type});
  final String? email;
  final OtpType type;
}

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

/// A `GoTrueClient` whose `resend(...)` does not hit the network: it just
/// records the call args in [calls] and either throws (when [throwOnResend]
/// is set) or resolves with an empty `ResendResponse`.
///
/// Built with `autoRefreshToken: false` so no periodic refresh timer is left
/// alive after the test (would trip `pumpAndSettle`'s "no timers pending"
/// invariant).
class _FakeGoTrueClient extends GoTrueClient {
  _FakeGoTrueClient({this.throwOnResend = false})
      : super(
          url: 'https://example.supabase.co/auth/v1',
          autoRefreshToken: false,
          httpClient: MockClient((request) async {
            return http.Response('{}', 200,
                headers: {'content-type': 'application/json'});
          }),
        );

  bool throwOnResend;
  final List<_CapturedResend> calls = [];

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    calls.add(_CapturedResend(email: email, type: type));
    if (throwOnResend) {
      throw Exception('boom');
    }
    return ResendResponse();
  }
}

/// `SupabaseClient` whose `auth` getter returns a caller-supplied
/// `_FakeGoTrueClient`. Lets the real `AuthService` exercise its body
/// (`_supabase.auth.resend(...)`) without touching the network.
class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(this.fakeAuth) : super(
          'https://example.supabase.co',
          'public-anon-key',
          httpClient: MockClient((request) async {
            return http.Response('{}', 200,
                headers: {'content-type': 'application/json'});
          }),
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

  final _FakeGoTrueClient fakeAuth;

  @override
  GoTrueClient get auth => fakeAuth;
}

class _StubAuthService extends AuthService {
  _StubAuthService(super.supabase);
  bool called = false;

  @override
  Future<void> resendVerificationEmail(String email) async {
    called = true;
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

  test('resendVerificationEmail calls auth.resend with OtpType.email', () async {
    final fakeAuth = _FakeGoTrueClient();
    final supabase = _FakeSupabaseClient(fakeAuth);

    // Real AuthService body runs end-to-end: it must call auth.resend with
    // OtpType.email (NOT OtpType.signup — the Sprint-8 T1 regression).
    final svc = AuthService(supabase);
    await svc.resendVerificationEmail('foo@bar.com');

    expect(fakeAuth.calls, hasLength(1));
    expect(fakeAuth.calls.single.email, 'foo@bar.com');
    expect(fakeAuth.calls.single.type, OtpType.email);
  });

  test('resendVerificationEmail wraps auth.resend errors as Exception',
      () async {
    final fakeAuth = _FakeGoTrueClient(throwOnResend: true);
    final supabase = _FakeSupabaseClient(fakeAuth);

    final svc = AuthService(supabase);
    await expectLater(
      () => svc.resendVerificationEmail('foo@bar.com'),
      throwsA(isA<Exception>()),
    );
    expect(fakeAuth.calls, hasLength(1));
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