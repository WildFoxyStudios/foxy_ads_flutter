// Widget tests for the fullscreen image lightbox
// (`lib/core/widgets/image_lightbox.dart`).
//
// `CachedNetworkImage` won't fetch real bytes in a widget test (no network
// access), so it renders its placeholder/error widget instead — that's
// fine, these tests assert on the lightbox's structural widgets (PageView,
// close button, page indicator text), not on decoded image pixels.
//
// NOTE: the placeholder is a `CircularProgressIndicator`, whose
// `AnimationController` repeats forever while mounted — `pumpAndSettle`
// would hang waiting for it to go idle. Once the lightbox is open we pump a
// bounded number of frames instead (`_pumpDialog`), never `pumpAndSettle`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foxy_ads/core/widgets/image_lightbox.dart';

Widget _buildTestApp({required List<String> images, int initialIndex = 0}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showImageLightbox(
                context,
                images: images,
                initialIndex: initialIndex,
              ),
              child: const Text('Open gallery'),
            ),
          ),
        );
      },
    ),
  );
}

/// Pumps enough bounded frames for the dialog's open/close transition to
/// finish, without `pumpAndSettle` (which never returns while the
/// placeholder's `CircularProgressIndicator` is mounted and animating).
Future<void> _pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'tapping the trigger opens a fullscreen PageView gallery with a page indicator',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(images: ['https://a/1.jpg', 'https://a/2.jpg']),
      );

      expect(find.byType(PageView), findsNothing);

      await tester.tap(find.text('Open gallery'));
      await _pumpDialog(tester);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the close button dismisses the lightbox',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(images: ['https://a/1.jpg', 'https://a/2.jpg']),
      );

      await tester.tap(find.text('Open gallery'));
      await _pumpDialog(tester);
      expect(find.byType(PageView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await _pumpDialog(tester);

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Open gallery'), findsOneWidget);
    },
  );

  testWidgets(
    'opens at the given initial index',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          images: ['https://a/1.jpg', 'https://a/2.jpg', 'https://a/3.jpg'],
          initialIndex: 2,
        ),
      );

      await tester.tap(find.text('Open gallery'));
      await _pumpDialog(tester);

      expect(find.text('3 / 3'), findsOneWidget);
    },
  );

  testWidgets(
    'no-ops when the images list is empty',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(images: const []));

      await tester.tap(find.text('Open gallery'));
      await _pumpDialog(tester);

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Open gallery'), findsOneWidget);
    },
  );
}
