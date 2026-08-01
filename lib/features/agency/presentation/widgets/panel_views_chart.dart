// Views-over-time chart for the Pro Dashboard (Task 6 of the B2B/agency
// sprint). Pure painter — no charting library. Renders ≤30 `DayPoint`s as a
// row of bars with rounded tops and a thin baseline, scaled to the maximum
// view count. Empty / all-zero series show a muted "Sin datos" placeholder
// instead of bars (the chart MUST be safe against an empty series and
// against `views == 0` for every day — no division by zero).

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/panel_stats.dart';

class PanelViewsChart extends StatelessWidget {
  final List<DayPoint> series;

  const PanelViewsChart({super.key, required this.series});

  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final maxViews = series.fold<int>(0, (m, p) => p.views > m ? p.views : m);
    final hasData = series.isNotEmpty && maxViews > 0;

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ViewsChartPainter(
          series: series,
          maxViews: maxViews,
          hasData: hasData,
        ),
      ),
    );
  }
}

class _ViewsChartPainter extends CustomPainter {
  final List<DayPoint> series;
  final int maxViews;
  final bool hasData;

  const _ViewsChartPainter({
    required this.series,
    required this.maxViews,
    required this.hasData,
  });

  static const double _padding = 8;
  static const double _topRadius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    // Baseline (always drawn — even on the empty state — so the chart's
    // footprint doesn't jump when data arrives).
    final baselineY = size.height - _padding;
    final baselinePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(_padding, baselineY),
      Offset(size.width - _padding, baselineY),
      baselinePaint,
    );

    if (!hasData) {
      _drawEmptyState(canvas, size);
      return;
    }

    final barPaint = Paint()..color = AppColors.primary;
    final ringPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final chartHeight = size.height - _padding * 2;
    final chartWidth = size.width - _padding * 2;
    final n = series.length;
    if (n <= 0) return;
    final barSlot = chartWidth / n;
    // Leave 2dp of breathing room between bars so the baseline ring stays
    // visible without clipping its neighbors.
    final barWidth = (barSlot - 2).clamp(1.0, barSlot);

    for (var i = 0; i < n; i++) {
      final p = series[i];
      final h = (p.views / maxViews) * chartHeight;
      final left = _padding + i * barSlot + 1;
      final top = size.height - _padding - h;
      final rect = Rect.fromLTWH(left, top, barWidth, h);

      // Rounded-top bar (no rounding on the bottom edge so it sits flush
      // against the baseline).
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(_topRadius),
        topRight: const Radius.circular(_topRadius),
      );
      canvas.drawRRect(rrect, barPaint);
      // 2px baseline ring (mirrors the project's dataviz mark spec).
      canvas.drawRRect(rrect, ringPaint);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final text = 'Sin datos';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (size.width - tp.width) / 2;
    final dy = (size.height - tp.height) / 2 - 8;
    tp.paint(canvas, Offset(dx.clamp(0, size.width), dy));
  }

  @override
  bool shouldRepaint(covariant _ViewsChartPainter old) {
    return old.series != series ||
        old.maxViews != maxViews ||
        old.hasData != hasData;
  }
}
