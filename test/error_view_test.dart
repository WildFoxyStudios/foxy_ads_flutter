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
          retryLabel: 'Volver al inicio',
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
          retryLabel: 'Retry',
          onRetry: () {},
        ),
      ));

      // The retry button renders the caller-supplied `retryLabel` (wired to
      // `AppLocalizations.commonErrorFallbackBackHome` by the router).
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    });

    testWidgets('hides the retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(_host(
        const ErrorView(
          title: 'Title',
          message: 'Body',
          retryLabel: 'Retry',
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('tapping the retry button invokes onRetry', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        ErrorView(
          title: 'Title',
          message: 'Body',
          retryLabel: 'Retry',
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
