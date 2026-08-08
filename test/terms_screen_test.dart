// Widget tests for the `/terminos` static screen (Sprint 12 Task 4).
//
// `TermsScreen` mirrors `privacy_screen.dart`'s structure exactly: a
// stateless `ConsumerWidget`, no provider dependencies beyond
// `AppLocalizations`, sections rendered from l10n strings, and a computed
// "last updated" footer. It deliberately skips a "section 5" (see the
// screen's doc comment — an upstream numbering gap), which this test
// verifies is NOT rendered.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/features/static/screens/terms_screen.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TermsScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'renders the app bar title and the first section',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Términos y Condiciones'), findsOneWidget);
      expect(find.text('1. Aceptación de los Términos'), findsOneWidget);
      expect(
        find.textContaining('Al usar Foxy Ads, aceptas estos términos'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'section numbering skips 5 (title "5." is never rendered)',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Section 4 exists, section 6 exists, but no section whose title
      // starts with "5." should ever be rendered (upstream gap ported
      // verbatim from the web copy).
      expect(find.text('4. Normas de Publicación'), findsOneWidget);
      expect(find.textContaining('5.'), findsNothing);
    },
  );

  testWidgets(
    'scrolling reveals the last section and the last-updated footer',
    (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final section12 = find.text('12. Contacto');
      await tester.scrollUntilVisible(
        section12,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(section12, findsOneWidget);

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
