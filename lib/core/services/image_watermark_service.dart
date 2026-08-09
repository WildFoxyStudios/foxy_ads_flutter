// Best-effort client-side image watermark (P9 B6).
//
// Mirrors (loosely) the web's `watermarkFile` helper
// (foxy_ads_web/src/lib/image.ts), which tiles a translucent "🦊 foxy ads"
// pattern onto uploaded listing photos via Canvas/OffscreenCanvas before
// upload. This is the Flutter equivalent: pure `dart:ui` (decode -> draw on
// a `Canvas` via `PictureRecorder` -> re-encode), so it ships with NO new
// pubspec dependency.
//
// Deliberately narrower than the web version — a single bottom-right label
// instead of a rotated tiled pattern — since `dart:ui` has no text-tiling
// primitive and reimplementing one is out of scope for a best-effort pass.
//
// Watermarking must never block a listing from publishing: any decode/draw/
// encode failure (corrupt bytes, unsupported format, zero-size image) is
// swallowed and the original bytes are returned unchanged.

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws a translucent [label] in the bottom-right corner of the image
/// encoded in [bytes] and re-encodes the result as PNG.
///
/// Returns [bytes] unchanged if anything goes wrong. Always returns a valid
/// image: either the watermarked PNG or the original input.
Future<Uint8List> watermarkImageBytes(
  Uint8List bytes, {
  String label = 'Foxy Ads',
}) async {
  ui.Image? decoded;
  ui.Image? rendered;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    decoded = frame.image;
    final width = decoded.width;
    final height = decoded.height;
    if (width <= 0 || height <= 0) return bytes;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawImage(decoded, ui.Offset.zero, ui.Paint());
    _drawWatermarkLabel(
      canvas,
      width.toDouble(),
      height.toDouble(),
      label,
    );

    final picture = recorder.endRecording();
    rendered = await picture.toImage(width, height);
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) return bytes;
    return byteData.buffer.asUint8List();
  } catch (_) {
    return bytes;
  } finally {
    decoded?.dispose();
    rendered?.dispose();
  }
}

void _drawWatermarkLabel(
  ui.Canvas canvas,
  double width,
  double height,
  String label,
) {
  final shortSide = width < height ? width : height;
  final fontSize = (shortSide * 0.055).clamp(12.0, 48.0);

  final paragraphBuilder =
      ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.right))
        ..pushStyle(
          ui.TextStyle(
            color: const ui.Color(0xCCFFFFFF), // white @ 80% alpha
            fontSize: fontSize,
            fontWeight: ui.FontWeight.w600,
            shadows: const [
              ui.Shadow(
                color: ui.Color(0x99000000),
                blurRadius: 4,
                offset: ui.Offset(0, 1),
              ),
            ],
          ),
        )
        ..addText(label);

  final maxTextWidth = width - 24;
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: maxTextWidth < 0 ? 0 : maxTextWidth));

  final dx = width - paragraph.width - 12;
  final dy = height - paragraph.height - 12;
  canvas.drawParagraph(
    paragraph,
    ui.Offset(dx < 0 ? 0 : dx, dy < 0 ? 0 : dy),
  );
}
