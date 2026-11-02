import 'package:flutter/material.dart';

/// Interactive chart displaying pitch contour curves according to the 5-degree pitch scale.
class PinyinToneContourChart extends StatelessWidget {
  final int selectedTone; // 1, 2, 3, 4

  const PinyinToneContourChart({
    super.key,
    this.selectedTone = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EBF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biểu đồ cao độ 5 mức (五度标记法)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Thanh $selectedTone',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3979C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _ToneContourPainter(selectedTone: selectedTone),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneContourPainter extends CustomPainter {
  final int selectedTone;

  _ToneContourPainter({required this.selectedTone});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFEDF2F7)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw 5 horizontal pitch reference lines (5=top, 1=bottom)
    final rowHeight = size.height / 4;
    for (int i = 0; i < 5; i++) {
      final y = size.height - (i * rowHeight);
      canvas.drawLine(Offset(24, y), Offset(size.width, y), linePaint);

      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(6, y - 6));
    }

    // Draw tone curves
    void drawToneCurve(int tone, Color color, double strokeWidth) {
      final path = Path();
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final startX = size.width * 0.25;
      final endX = size.width * 0.85;

      switch (tone) {
        case 1: // 55: High level
          final y5 = size.height - (4 * rowHeight);
          path.moveTo(startX, y5);
          path.lineTo(endX, y5);
          break;
        case 2: // 35: Rising from 3 to 5
          final y3 = size.height - (2 * rowHeight);
          final y5 = size.height - (4 * rowHeight);
          path.moveTo(startX, y3);
          path.quadraticBezierTo((startX + endX) / 2, y3, endX, y5);
          break;
        case 3: // 214: Dipping 2 -> 1 -> 4
          final y2 = size.height - (1 * rowHeight);
          final y1 = size.height;
          final y4 = size.height - (3 * rowHeight);
          path.moveTo(startX, y2);
          path.quadraticBezierTo(startX + (endX - startX) * 0.4, y1, endX, y4);
          break;
        case 4: // 51: Falling 5 -> 1
          final y5 = size.height - (4 * rowHeight);
          final y1 = size.height;
          path.moveTo(startX, y5);
          path.lineTo(endX, y1);
          break;
      }
      canvas.drawPath(path, paint);
    }

    // Background curves for unselected tones
    for (int t = 1; t <= 4; t++) {
      if (t != selectedTone) {
        drawToneCurve(t, const Color(0xFFE2E8F0), 1.5);
      }
    }

    // Highlight active tone
    drawToneCurve(selectedTone, const Color(0xFF5B9BE6), 3.5);
  }

  @override
  bool shouldRepaint(covariant _ToneContourPainter oldDelegate) {
    return oldDelegate.selectedTone != selectedTone;
  }
}
