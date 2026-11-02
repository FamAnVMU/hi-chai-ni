import 'package:flutter/material.dart';

/// CustomPainter rendering the classical Chinese Mizige (米字格) calligraphy practice grid.
class MizigePainter extends CustomPainter {
  final Color borderColor;
  final Color guidelineColor;
  final double borderWidth;

  const MizigePainter({
    this.borderColor = const Color(0xFFCBD5E1),
    this.guidelineColor = const Color(0xFFE2E8F0),
    this.borderWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final dashPaint = Paint()
      ..color = guidelineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw outer boundary box
    canvas.drawRect(rect, borderPaint);

    final midX = size.width / 2;
    final midY = size.height / 2;

    // 2. Draw dashed cross (+)
    _drawDashedLine(canvas, Offset(midX, 0), Offset(midX, size.height), dashPaint);
    _drawDashedLine(canvas, Offset(0, midY), Offset(size.width, midY), dashPaint);

    // 3. Draw dashed diagonals (x) forming the "米" character
    _drawDashedLine(canvas, Offset.zero, Offset(size.width, size.height), dashPaint);
    _drawDashedLine(canvas, Offset(size.width, 0), Offset(0, size.height), dashPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dashWidth = 5.0, double dashSpace = 4.0}) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final totalDistance = Offset(dx, dy).distance;

    final unitX = dx / totalDistance;
    final unitY = dy / totalDistance;

    double currentDist = 0.0;
    while (currentDist < totalDistance) {
      final start = Offset(p1.dx + unitX * currentDist, p1.dy + unitY * currentDist);
      final remaining = totalDistance - currentDist;
      final step = remaining < dashWidth ? remaining : dashWidth;
      final end = Offset(start.dx + unitX * step, start.dy + unitY * step);

      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant MizigePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.guidelineColor != guidelineColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
