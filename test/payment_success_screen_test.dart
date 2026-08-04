// Widget tests for the `/payment/success` return target (Sprint 7 T3).
//
// `PaymentSuccessScreen` runs `paymentsService.resolveSession(sessionId)` in
// `initState` and switches between 5 states (loading/ready/pending/error/
// missingSession). We override `paymentsServiceProvider` with a fake
// `PaymentsService` (extending the real class, NOT wrapping it) so the
// screen's `ref.read(paymentsServiceProvider)` call picks it up without a
// real Supabase client round-trip.
//
// Follows the same fake-service + `ProviderScope.override` pattern as
// `test/agency_profile_screen_test.dart` / `test/panel_gate_test.dart`, and
// the `MaterialApp` (not `.router`) + `Locale('es')` + l10n delegates setup
// established across the widget-test suite (screens crash otherwise because
// `AppLocalizations.of(context)` is null).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, SupabaseClient;

import 'package:foxy_ads/features/payments/data/payments_providers.dart';
import 'package:foxy_ads/features/payments/data/payments_service.dart';
import 'package:foxy_ads/features/payments/presentation/screens/payment_success_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

/// Fake `PaymentsService` whose `resolveSession` is fully scripted by the
/// test (either returns a fixed tuple or throws). `createCheckout` is unused
/// by this screen so it's left inherited (would throw if ever called).
class FakePaymentsService extends PaymentsService {
  FakePaymentsService(super.supabase, {this.result, this.error});

  final ({String? listingId, String? title})? result;
  final Object? error;

  @override
  Future<({String? listingId, String? title})> resolveSession(
    String sessionId,
  ) async {
    if (error != null) throw error!;
    return result!;
  }
}

SupabaseClient _dummySupabase() => SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

Widget _buildTestApp({
  String? sessionId,
  ({String? listingId, String? title})? result,
  Object? error,
}) {
  final fake = FakePaymentsService(
    _dummySupabase(),
    result: result,
    error: error,
  );
  return ProviderScope(
    overrides: [
      paymentsServiceProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PaymentSuccessScreen(sessionId: sessionId),
    ),
  );
}

void main() {
  testWidgets(
    'sessionId == null renders the missing-session error state',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(sessionId: null));
      await tester.pumpAndSettle();

      expect(
        find.text('Falta el identificador de sesión.'),
        findsOneWidget,
      );
      expect(find.text('Volver a mis anuncios'), findsOneWidget);
    },
  );

  testWidgets(
    'resolveSession returning listingId+title renders the ready state',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          sessionId: 'cs_test_abc',
          result: (listingId: 'l1', title: 'Coche'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¡Listo! Tu anuncio está destacado.'), findsOneWidget);
      expect(find.text('Coche'), findsOneWidget);
      expect(find.text('Ver anuncio'), findsOneWidget);
    },
  );

  testWidgets(
    'resolveSession returning (null, null) renders the pending state',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          sessionId: 'cs_test_pending',
          result: (listingId: null, title: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('unos minutos'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets(
    'resolveSession throwing renders the error state',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          sessionId: 'cs_test_error',
          error: Exception('network down'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos verificar el pago.'), findsOneWidget);
      expect(find.text('Volver a mis anuncios'), findsOneWidget);
    },
  );
}
