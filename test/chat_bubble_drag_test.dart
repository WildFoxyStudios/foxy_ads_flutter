// Widget tests for `ChatBubble`'s drag-to-reposition behaviour (Sprint 12,
// Task 1 — draggable + position-persistent Foxy bubble).
//
// The bubble is normally mounted alongside `MaterialApp.router`'s `builder`
// child inside an `Overlay` (see `main.dart`'s doc comment on why: its
// `Tooltip`/`showModalBottomSheet` need an `Overlay`/`Navigator` ancestor
// that isn't otherwise available). These tests reproduce that same shape
// with a plain `MaterialApp` + `Navigator` so `find.byType(Positioned)`
// resolves to the bubble's own `Positioned` (not `MaterialApp`'s internal
// ones) by scoping the search to the `Stack` that hosts it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:foxy_ads/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:foxy_ads/l10n/app_localizations.dart';

const _screenSize = Size(400, 800);

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Stack(children: [ChatBubble()]),
      ),
    ),
  );
}

Offset _bubblePosition(WidgetTester tester) {
  final positioned = tester.widget<Positioned>(
    find.descendant(
      of: find.byType(ChatBubble),
      matching: find.byType(Positioned),
    ),
  );
  return Offset(positioned.left!, positioned.top!);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatBubble drag', () {
    testWidgets('renders at the default bottom-right position', (
      tester,
    ) async {
      _setScreenSize(tester, _screenSize);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final position = _bubblePosition(tester);
      // Default: bottom-right, size=60, margin=16, bottom offset=90.
      expect(position.dx, closeTo(_screenSize.width - 60 - 16, 0.01));
      expect(position.dy, closeTo(_screenSize.height - 60 - 90, 0.01));
    });

    testWidgets('dragging the bubble moves it and persists the position', (
      tester,
    ) async {
      _setScreenSize(tester, _screenSize);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final before = _bubblePosition(tester);

      await tester.drag(find.byType(ChatBubble), const Offset(-80, -120));
      await tester.pumpAndSettle();

      final after = _bubblePosition(tester);
      expect(after, isNot(equals(before)));
      // Moved up and to the left, roughly by the drag delta (clamped).
      expect(after.dx, lessThan(before.dx));
      expect(after.dy, lessThan(before.dy));

      // Persisted: a fresh SharedPreferences read sees the saved position.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('foxy_chat_position');
      expect(raw, isNotNull);
      final parts = raw!.split(',').map(double.parse).toList();
      expect(parts[0], closeTo(after.dx, 0.01));
      expect(parts[1], closeTo(after.dy, 0.01));
    });

    testWidgets('a tap below the drag threshold does not move the bubble', (
      tester,
    ) async {
      _setScreenSize(tester, _screenSize);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final before = _bubblePosition(tester);

      // A plain tap synthesizes a down+up with no movement in between, so
      // it stays well under the 8px drag threshold.
      await tester.tap(find.byType(ChatBubble));
      await tester.pump();

      final after = _bubblePosition(tester);
      expect(after, equals(before));

      // Nothing should have been persisted either — no real drag occurred.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('foxy_chat_position'), isNull);
    });

    testWidgets('a drag far past the screen edge stays clamped on-screen', (
      tester,
    ) async {
      _setScreenSize(tester, _screenSize);

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Drag way off the top-left corner of the screen.
      await tester.drag(find.byType(ChatBubble), const Offset(-2000, -2000));
      await tester.pumpAndSettle();

      final after = _bubblePosition(tester);
      expect(after.dx, greaterThanOrEqualTo(0));
      expect(after.dy, greaterThanOrEqualTo(0));
      expect(after.dx, lessThanOrEqualTo(_screenSize.width - 60));
      expect(after.dy, lessThanOrEqualTo(_screenSize.height - 60));
    });

    testWidgets(
      'a position saved off-screen (e.g. from a rotation) is re-clamped on '
      'the next build',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'foxy_chat_position': '900,1500',
        });
        _setScreenSize(tester, _screenSize);

        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final position = _bubblePosition(tester);
        expect(position.dx, lessThanOrEqualTo(_screenSize.width - 60));
        expect(position.dy, lessThanOrEqualTo(_screenSize.height - 60));
      },
    );
  });
}
