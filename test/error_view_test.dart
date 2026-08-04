// Widget tests for the friendly error view used by the top-level router
// `errorBuilder` (Sprint 8 Task 3).
//
// The view renders title + message in a centered column, plus an optional
// retry button when `onRetry` is provided. The tests exercise the visible
// surface (no localization plumbing — `ErrorView` is a pure stateless
// widget that receives its strings from the caller).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxy_ads/core/widgets/error_view.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('ErrorView', () {
    testWidgets('renders title and message', (tester) async {
      await tester.pumpWidget(_host(
        const ErrorView(
          title: 'Algo salió mal',
          message: 'No pudimos cargar esta página.',
        ),
      ));

      expect(find.text('Algo salió mal'), findsOneWidget);
      expect(find.text('No pudimos cargar esta página.'), findsOneWidget);
    });

    testWidgets('shows the retry button when onRetry is provided',
        (tester) async {
      await tester.pumpWidget(_host(
        ErrorView(
          title: 'Title',
          message: 'Body',
          onRetry: () {},
        ),
      ));

      // Both labels share a single button slot in the widget — the title
      // "Volver al inicio" is the retry/back-home string passed in by the
      // router. Either label format the brief allows for is acceptable.
      final hasRetry = find.byType(ElevatedButton).evaluate().isNotEmpty ||
          find.byType(TextButton).evaluate().isNotEmpty;
      expect(hasRetry, isTrue,
          reason: 'Expected a button when onRetry is non-null');
    });

    testWidgets('hides the retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(_host(
        const ErrorView(
          title: 'Title',
          message: 'Body',
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('tapping the retry button invokes onRetry', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        ErrorView(
          title: 'Title',
          message: 'Body',
          onRetry: () => taps++,
        ),
      ));

      // Tap whichever button class the widget chose.
      final elevated = find.byType(ElevatedButton);
      final textBtn = find.byType(TextButton);
      if (elevated.evaluate().isNotEmpty) {
        await tester.tap(elevated);
      } else {
        await tester.tap(textBtn);
      }
      await tester.pump();

      expect(taps, 1);
    });
  });
}
