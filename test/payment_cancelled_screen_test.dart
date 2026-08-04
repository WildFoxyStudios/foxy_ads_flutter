// Widget tests for the `/payment/cancelled` return target (Sprint 7 T3).
//
// `PaymentCancelledScreen` is a pure `ConsumerWidget` with no async state —
// no provider overrides are needed. We only wrap it in a properly-localized
// `MaterialApp` (else `AppLocalizations.of(context)` is null and the screen
// crashes, per the established gotcha across this suite).
//
// The "Reintentar" button's destination differs based on whether a
// `listingId` was passed (`/promote/:id` vs `/my-listings`), but the button
// uses `context.push(...)`, which requires a `Navigator`/router ancestor to
// resolve at tap-time. Per the task's guidance we assert the buttons'
// *presence* rather than tapping + asserting navigation, to avoid pulling in
// a full `GoRouter` harness for a screen this simple.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/payments/presentation/screens/payment_cancelled_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Widget _buildTestApp({String? listingId}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PaymentCancelledScreen(listingId: listingId),
  );
}

void main() {
  testWidgets(
    'renders the "pago cancelado" title and body',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Title appears twice: once in the AppBar, once in the body heading.
      expect(find.text('Pago cancelado'), findsNWidgets(2));
      expect(
        find.text(
          'No se ha realizado ningún cargo. Puedes intentarlo de nuevo cuando quieras.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows "Reintentar" and "Volver al inicio" buttons regardless of listingId',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(listingId: 'l1'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Volver al inicio'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows the "Reintentar" button when listingId is null too',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(listingId: null));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the "¿Necesitas ayuda?" help link',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('¿Necesitas ayuda?'), findsOneWidget);
      expect(find.text('Contactar soporte'), findsOneWidget);
    },
  );
}
