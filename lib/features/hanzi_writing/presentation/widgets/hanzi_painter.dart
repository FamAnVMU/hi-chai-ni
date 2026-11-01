import 'package:flutter/material.dart';
import '../../domain/models/stroke_models.dart';

/// CustomPainter rendering smooth calligraphy strokes, optional character watermark,
/// and step-by-step stroke guidance.
class HanziPainter extends CustomPainter {
  final List<DrawnStroke> strokes;
  final DrawnStroke? activeStroke;
  final String? character;
  final HanziStrokeData? strokeData;
  final WritingMode mode;
  final int? highlightedStrokeOrder;
  final Color watermarkColor;
  final Color highlightStrokeColor;

  const HanziPainter({
    required this.strokes,
    this.activeStroke,
    this.character,
    this.strokeData,
    this.mode = WritingMode.tracing,
    this.highlightedStrokeOrder,
    this.watermarkColor = const Color(0x33A3D635),
    this.highlightStrokeColor = const Color(0xFFA3D635),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Tracing Watermark & Next Stroke Guide (if in Tracing Mode)
    if (mode == WritingMode.tracing && character != null) {
      _drawCharacterWatermark(canvas, size);
    }

    // 2. Draw standard stroke guidance arrow/line if requested
    if (strokeData != null && highlightedStrokeOrder != null) {
      _drawHighlightedStrokeGuide(canvas, size);
    }

    // 3. Draw committed user strokes
    for (final stroke in strokes) {
      _drawSingleStroke(canvas, stroke);
    }

    // 4. Draw currently active in-flight stroke
    if (activeStroke != null && activeStroke!.isNotEmpty) {
      _drawSingleStroke(canvas, activeStroke!);
    }
  }

  void _drawCharacterWatermark(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontSize: size.width * 0.76,
          fontWeight: FontWeight.bold,
          color: watermarkColor,
          fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC', 'PingFang SC', 'sans-serif'],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final xOffset = (size.width - textPainter.width) / 2;
    final yOffset = (size.height - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(xOffset, yOffset));
  }

  void _drawHighlightedStrokeGuide(Canvas canvas, Size size) {
    final stdStroke = strokeData!.strokes.firstWhere(
      (s) => s.order == highlightedStrokeOrder,
      orElse: () => strokeData!.strokes.first,
    );

    final start = Offset(
      stdStroke.normalizedStart.dx * size.width,
      stdStroke.normalizedStart.dy * size.height,
    );
    final end = Offset(
      stdStroke.normalizedEnd.dx * size.width,
      stdStroke.normalizedEnd.dy * size.height,
    );

    final guidePaint = Paint()
      ..color = highlightStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, guidePaint);

    // Draw start dot indicator
    final dotPaint = Paint()
      ..color = highlightStrokeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(start, 6.0, dotPaint);
  }

  void _drawSingleStroke(Canvas canvas, DrawnStroke stroke) {
    if (stroke.points.isEmpty) return;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      final dotPaint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.offset, (stroke.baseStrokeWidth * p.pressure) / 2, dotPaint);
      return;
    }

    final points = stroke.points;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Dynamic stroke width scaled by stylus/finger touch pressure
      final width = stroke.baseStrokeWidth * ((p1.pressure + p2.pressure) / 2).clamp(0.6, 1.8);

      final linePaint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawLine(p1.offset, p2.offset, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HanziPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.character != character ||
        oldDelegate.mode != mode ||
        oldDelegate.highlightedStrokeOrder != highlightedStrokeOrder;
  }
}
