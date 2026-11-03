import 'package:flutter/material.dart';
import '../../domain/models/hanzi_models.dart';

/// Renders the user's active touch gesture path on the canvas with calligraphy ink styling.
class UserDrawingPainter extends CustomPainter {
  final List<Point2D> points;
  final Color strokeColor;
  final double strokeWidth;

  const UserDrawingPainter({
    required this.points,
    this.strokeColor = const Color(0xFF2563EB),
    this.strokeWidth = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(Offset(points.first.x, points.first.y), strokeWidth / 2, Paint()..color = strokeColor);
      return;
    }

    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    for (int i = 1; i < points.length; i++) {
      // Quadratic bezier curve smoothing between points
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.x + p1.x) / 2;
      final midY = (p0.y + p1.y) / 2;
      path.quadraticBezierTo(p0.x, p0.y, midX, midY);
    }
    path.lineTo(points.last.x, points.last.y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant UserDrawingPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
