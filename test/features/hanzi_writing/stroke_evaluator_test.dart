import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/hanzi_writing/hanzi_writing.dart';

void main() {
  const bank = HanziStrokeBank();
  const evaluator = StrokeEvaluator();
  const canvasSize = Size(320.0, 320.0);

  DrawnStroke createTestStroke({
    required Offset start,
    required Offset end,
    int steps = 10,
  }) {
    final points = <StrokePoint>[];
    final dx = (end.dx - start.dx) / steps;
    final dy = (end.dy - start.dy) / steps;

    for (int i = 0; i <= steps; i++) {
      points.add(
        StrokePoint(
          offset: Offset(start.dx + dx * i, start.dy + dy * i),
          pressure: 1.0,
          timestamp: DateTime.now().add(Duration(milliseconds: i * 20)),
        ),
      );
    }

    return DrawnStroke(points: points);
  }

  group('StrokeEvaluator Mathematical & Stroke Order Tests', () {
    test('1. Perfect stroke order on "十" (先横后竖) achieves 100% accuracy', () {
      final shiData = bank.getStrokeData('十')!;

      // Stroke 1: Horizontal (Ngang) from left to right: (64, 144) to (256, 144)
      final stroke1 = createTestStroke(
        start: const Offset(64, 144),
        end: const Offset(256, 144),
      );

      // Stroke 2: Vertical (Sổ) from top to bottom: (160, 64) to (160, 256)
      final stroke2 = createTestStroke(
        start: const Offset(160, 64),
        end: const Offset(160, 256),
      );

      final result = evaluator.evaluate(
        drawnStrokes: [stroke1, stroke2],
        canvasSize: canvasSize,
        strokeData: shiData,
        mode: WritingMode.tracing,
      );

      expect(result.scorePercent, equals(100));
      expect(result.correctStrokeCount, equals(2));
      expect(result.totalStandardStrokes, equals(2));
      expect(result.isPassed, isTrue);
      expect(result.strokeFeedbackList.first, contains('Chuẩn hướng và thứ tự'));
    });

    test('2. Reversed stroke direction (drawing vertical bottom to top) is detected and penalized', () {
      final shiData = bank.getStrokeData('十')!;

      // Stroke 1: Normal Horizontal
      final stroke1 = createTestStroke(
        start: const Offset(64, 144),
        end: const Offset(256, 144),
      );

      // Stroke 2: INVERTED Vertical from bottom (160, 256) to top (160, 64)
      final stroke2Inverted = createTestStroke(
        start: const Offset(160, 256),
        end: const Offset(160, 64),
      );

      final result = evaluator.evaluate(
        drawnStrokes: [stroke1, stroke2Inverted],
        canvasSize: canvasSize,
        strokeData: shiData,
        mode: WritingMode.tracing,
      );

      expect(result.scorePercent, equals(50)); // Only 1/2 strokes correct
      expect(result.correctStrokeCount, equals(1));
      expect(result.strokeFeedbackList.any((msg) => msg.contains('Viết ngược chiều')), isTrue);
    });

    test('3. Inverted stroke order (drawing Sổ before Ngang) fails sequence check', () {
      final shiData = bank.getStrokeData('十')!;

      // User draws Sổ FIRST (wrong order!)
      final strokeVerticalFirst = createTestStroke(
        start: const Offset(160, 64),
        end: const Offset(160, 256),
      );

      // User draws Ngang SECOND
      final strokeHorizontalSecond = createTestStroke(
        start: const Offset(64, 144),
        end: const Offset(256, 144),
      );

      final result = evaluator.evaluate(
        drawnStrokes: [strokeVerticalFirst, strokeHorizontalSecond],
        canvasSize: canvasSize,
        strokeData: shiData,
        mode: WritingMode.tracing,
      );

      // Since stroke 1 was expected to be horizontal (angle ~0), but vertical was drawn (angle ~pi/2)
      expect(result.correctStrokeCount, lessThan(2));
    });

    test('4. Character without verified stroke data returns safe freeform result with no penalty', () {
      // Character not in stroke bank
      final unknownData = bank.getStrokeData('难');
      expect(unknownData, isNull);

      final stroke = createTestStroke(
        start: const Offset(50, 50),
        end: const Offset(200, 200),
      );

      final result = evaluator.evaluate(
        drawnStrokes: [stroke],
        canvasSize: canvasSize,
        strokeData: unknownData,
        mode: WritingMode.freeform,
      );

      expect(result.hasStandardStrokeData, isFalse);
      expect(result.strokeOrderAccuracy, equals(1.0));
      expect(result.overallVerdict, contains('Chưa có dữ liệu nét chuẩn'));
    });

    test('5. Empty canvas returns 0 score with prompt to draw', () {
      final shiData = bank.getStrokeData('十')!;

      final result = evaluator.evaluate(
        drawnStrokes: [],
        canvasSize: canvasSize,
        strokeData: shiData,
        mode: WritingMode.freeform,
      );

      expect(result.scorePercent, equals(0));
      expect(result.overallVerdict, contains('Khung vẽ trống'));
    });
  });
}
