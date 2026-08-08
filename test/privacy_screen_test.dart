// Widget tests for the `/privacidad` static screen (Sprint 12 Task 4).
//
// `PrivacyScreen` is a stateless `ConsumerWidget` with no provider
// dependencies other than `AppLocalizations` — it just renders 7 hand-coded
// `_Section`s from l10n strings plus a "last updated" footer computed from
// `DateTime.now()`. No `ProviderScope` overrides are needed; the plain
// `MaterialApp` + l10n-delegate setup established across the widget-test
// suite is enough to pump it without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/static/screens/privacy_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PrivacyScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'renders the app bar title and the first section (title + intro + bulleted item)',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Política de Privacidad'), findsOneWidget);
      expect(find.text('1. Información que Recopilamos'), findsOneWidget);
      expect(
        find.text('En Foxy Ads recopilamos la siguiente información:'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Información de registro'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'scrolling reveals the last section and the last-updated footer',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Section 7 ("Contacto") and the footer are below the fold — scroll
      // them into view via the screen's own ListView before asserting.
      final section7 = find.text('7. Contacto');
      await tester.scrollUntilVisible(
        section7,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(section7, findsOneWidget);

      final footer = find.textContaining('Última actualización:');
      await tester.scrollUntilVisible(
        footer,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(footer, findsOneWidget);
    },
  );
}
