import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/engine/svg_path_parser.dart';
import '../../domain/models/hanzi_models.dart';

/// CustomPainter that renders a Hanzi character with:
/// - Background TianZiGe or MiZiGe calligraphy grid
/// - Faint character outline
/// - Filled completed strokes
/// - Currently animating stroke with progression
/// - Stroke order sequence numbers
class HanziCharacterPainter extends CustomPainter {
  final HanziCharacter? character;
  final int completedStrokesCount;
  final int? activeStrokeIndex;
  final double animationProgress; // 0.0 to 1.0
  final bool showOutline;
  final bool showStrokeNumbers;
  final WritingGridType gridType;
  final Color outlineColor;
  final Color strokeColor;
  final Color activeStrokeColor;
  final Color gridColor;

  HanziCharacterPainter({
    required this.character,
    this.completedStrokesCount = 0,
    this.activeStrokeIndex,
    this.animationProgress = 1.0,
    this.showOutline = true,
    this.showStrokeNumbers = false,
    this.gridType = WritingGridType.miZiGe,
    this.outlineColor = const Color(0xFFE2E8F0),
    this.strokeColor = const Color(0xFF1E293B),
    this.activeStrokeColor = const Color(0xFF2563EB),
    this.gridColor = const Color(0xFFF1F5F9),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw calligraphy grid
    _drawGrid(canvas, size);

    if (character == null || character!.strokes.isEmpty) return;

    final width = size.width;
    final height = size.height;
    const padding = 24.0;

    // 2. Draw faint outline of the entire character
    if (showOutline) {
      final outlinePaint = Paint()
        ..color = outlineColor
        ..style = PaintingStyle.fill;

      for (int i = 0; i < character!.strokes.length; i++) {
        final path = SvgPathParser.parse(
          character!.strokes[i],
          width: width,
          height: height,
          padding: padding,
        );
        canvas.drawPath(path, outlinePaint);
      }
    }

    // 3. Draw completed strokes
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final effectiveCompleted = math.min(completedStrokesCount, character!.strokes.length);
    for (int i = 0; i < effectiveCompleted; i++) {
      if (activeStrokeIndex != null && i == activeStrokeIndex) continue;
      final path = SvgPathParser.parse(
        character!.strokes[i],
        width: width,
        height: height,
        padding: padding,
      );
      canvas.drawPath(path, strokePaint);
    }

    // 4. Draw active animating stroke (if any)
    if (activeStrokeIndex != null &&
        activeStrokeIndex! >= 0 &&
        activeStrokeIndex! < character!.strokes.length) {
      final activePath = SvgPathParser.parse(
        character!.strokes[activeStrokeIndex!],
        width: width,
        height: height,
        padding: padding,
      );

      final activePaint = Paint()
        ..color = activeStrokeColor
        ..style = PaintingStyle.fill;

      if (animationProgress >= 0.99) {
        canvas.drawPath(activePath, activePaint);
      } else if (animationProgress > 0.0) {
        // Clip along median path progression
        canvas.save();
        final clipPath = _createProgressClipPath(
          size: size,
          padding: padding,
          strokeIndex: activeStrokeIndex!,
          progress: animationProgress,
        );
        if (clipPath != null) {
          canvas.clipPath(clipPath);
        }
        canvas.drawPath(activePath, activePaint);
        canvas.restore();
      }
    }

    // 5. Draw stroke order numbers
    if (showStrokeNumbers) {
      _drawStrokeNumbers(canvas, size, padding);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (gridType == WritingGridType.none) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw outer boundary
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      borderPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final midX = size.width / 2.0;
    final midY = size.height / 2.0;

    // Draw cross lines (田字格)
    _drawDashedLine(canvas, Offset(0, midY), Offset(size.width, midY), linePaint);
    _drawDashedLine(canvas, Offset(midX, 0), Offset(midX, size.height), linePaint);

    // Draw diagonal lines if MiZiGe (米字格)
    if (gridType == WritingGridType.miZiGe) {
      _drawDashedLine(canvas, const Offset(0, 0), Offset(size.width, size.height), linePaint);
      _drawDashedLine(canvas, Offset(size.width, 0), Offset(0, size.height), linePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final count = (distance / (dashWidth + dashSpace)).floor();
    final unitX = dx / distance;
    final unitY = dy / distance;

    for (int i = 0; i < count; i++) {
      final start = Offset(
        p1.dx + (dashWidth + dashSpace) * i * unitX,
        p1.dy + (dashWidth + dashSpace) * i * unitY,
      );
      final end = Offset(
        start.dx + dashWidth * unitX,
        start.dy + dashWidth * unitY,
      );
      canvas.drawLine(start, end, paint);
    }
  }

  Path? _createProgressClipPath({
    required Size size,
    required double padding,
    required int strokeIndex,
    required double progress,
  }) {
    if (character == null || strokeIndex >= character!.medians.length) return null;
    final median = character!.medians[strokeIndex];
    if (median.isEmpty) return null;

    final effectiveWidth = size.width - 2 * padding;
    final effectiveHeight = size.height - 2 * padding;
    final scale = (effectiveWidth < effectiveHeight ? effectiveWidth : effectiveHeight) / 1024.0;
    final xOffset = padding + (effectiveWidth - 1024.0 * scale) / 2.0;
    final yOffset = padding + (effectiveHeight - 1024.0 * scale) / 2.0;

    double toScreenX(num x) => xOffset + x * scale;
    double toScreenY(num y) => yOffset + (900.0 - y) * scale;

    final points = median.map((p) => Offset(toScreenX(p.x), toScreenY(p.y))).toList();
    if (points.length == 1) {
      final path = Path();
      path.addOval(Rect.fromCircle(center: points.first, radius: 80 * scale * progress));
      return path;
    }

    // Interpolate point along curve
    final path = Path();
    final brushRadius = 120.0 * scale;

    final targetIndex = (progress * (points.length - 1)).clamp(0.0, (points.length - 1).toDouble());
    final baseIdx = targetIndex.floor();
    final frac = targetIndex - baseIdx;

    for (int i = 0; i <= baseIdx; i++) {
      path.addOval(Rect.fromCircle(center: points[i], radius: brushRadius));
      if (i > 0) {
        path.addPolygon([
          points[i - 1],
          points[i],
        ], false);
      }
    }

    if (baseIdx < points.length - 1 && frac > 0.0) {
      final interPoint = Offset(
        points[baseIdx].dx + (points[baseIdx + 1].dx - points[baseIdx].dx) * frac,
        points[baseIdx].dy + (points[baseIdx + 1].dy - points[baseIdx].dy) * frac,
      );
      path.addOval(Rect.fromCircle(center: interPoint, radius: brushRadius));
    }

    return path;
  }

  void _drawStrokeNumbers(Canvas canvas, Size size, double padding) {
    final effectiveWidth = size.width - 2 * padding;
    final effectiveHeight = size.height - 2 * padding;
    final scale = (effectiveWidth < effectiveHeight ? effectiveWidth : effectiveHeight) / 1024.0;
    final xOffset = padding + (effectiveWidth - 1024.0 * scale) / 2.0;
    final yOffset = padding + (effectiveHeight - 1024.0 * scale) / 2.0;

    double toScreenX(num x) => xOffset + x * scale;
    double toScreenY(num y) => yOffset + (900.0 - y) * scale;

    final badgeRadius = 11.0;
    final circlePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = 0; i < character!.medians.length; i++) {
      final median = character!.medians[i];
      if (median.isEmpty) continue;
      final start = median.first;
      final center = Offset(toScreenX(start.x), toScreenY(start.y));

      // Draw red circle
      canvas.drawCircle(center, badgeRadius, circlePaint);

      // Draw number
      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HanziCharacterPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.completedStrokesCount != completedStrokesCount ||
        oldDelegate.activeStrokeIndex != activeStrokeIndex ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.showOutline != showOutline ||
        oldDelegate.showStrokeNumbers != showStrokeNumbers ||
        oldDelegate.gridType != gridType;
  }
}
