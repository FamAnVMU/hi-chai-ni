import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/stroke_models.dart';

/// Pure mathematical evaluator that inspects stroke sequence, trajectory vectors,
/// and start positions against standard Chinese calligraphy rules.
class StrokeEvaluator {
  const StrokeEvaluator();

  /// Evaluates user's drawn strokes against verified standard stroke order.
  WritingEvaluationResult evaluate({
    required List<DrawnStroke> drawnStrokes,
    required Size canvasSize,
    required HanziStrokeData? strokeData,
    required WritingMode mode,
  }) {
    final isTracing = mode == WritingMode.tracing;

    // Case 1: Unverified or missing stroke order data -> Free Writing Mode (Luyện viết tự do)
    if (strokeData == null) {
      return WritingEvaluationResult(
        strokeOrderAccuracy: 1.0,
        correctStrokeCount: drawnStrokes.length,
        totalStandardStrokes: drawnStrokes.length,
        userDrawnStrokesCount: drawnStrokes.length,
        isTracingMode: isTracing,
        hasStandardStrokeData: false,
        strokeFeedbackList: const [
          'Chưa có dữ liệu thứ tự nét chuẩn cho chữ này. Hoàn thành ở chế độ luyện viết tự do.'
        ],
        overallVerdict:
            'Chưa có dữ liệu nét chuẩn cho chữ này. Bạn đã hoàn thành ${drawnStrokes.length} nét ở chế độ luyện viết tự do (không phạt điểm).',
      );
    }

    final standardStrokes = strokeData.strokes;
    final totalStandard = standardStrokes.length;
    final userCount = drawnStrokes.length;

    if (userCount == 0) {
      return WritingEvaluationResult(
        strokeOrderAccuracy: 0.0,
        correctStrokeCount: 0,
        totalStandardStrokes: totalStandard,
        userDrawnStrokesCount: 0,
        isTracingMode: isTracing,
        strokeFeedbackList: const ['Bạn chưa viết nét nào trên khung lưới.'],
        overallVerdict: 'Khung vẽ trống. Hãy viết theo thứ tự nét mẫu.',
      );
    }

    final feedbackList = <String>[];
    int correctStrokes = 0;

    // Normalize user strokes into [0, 1] relative bounding box
    final normalizedStrokes =
        drawnStrokes.map((s) => s.normalized(canvasSize)).toList();

    // Compare each stroke pairwise up to min(userCount, totalStandard)
    final compareCount = math.min(userCount, totalStandard);

    for (int i = 0; i < compareCount; i++) {
      final userStroke = normalizedStrokes[i];
      final stdStroke = standardStrokes[i];

      final userVec = userStroke.directionVector;

      if (userStroke.points.length < 2 || userVec.distance < 0.03) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Quá ngắn hoặc chỉ là một điểm chạm.');
        continue;
      }

      // 1. Angular direction comparison
      final userAngle = userStroke.angleRadians;
      final stdAngle = stdStroke.expectedAngle;
      var diffAngle = (userAngle - stdAngle).abs();
      if (diffAngle > math.pi) {
        diffAngle = 2 * math.pi - diffAngle;
      }

      final cosSimilarity = math.cos(diffAngle);

      // Check reverse / inverted stroke direction
      if (cosSimilarity < -0.3) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Viết ngược chiều nét bút thuận.');
        continue;
      }

      // 2. Start point proximity in normalized canvas
      final startDist = (userStroke.startPoint!.offset - stdStroke.normalizedStart).distance;

      // Allow slightly wider tolerance in freeform mode than tracing mode
      final startTolerance = isTracing ? 0.35 : 0.45;

      if (startDist > startTolerance) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Điểm đặt bút bị lệch so với vị trí chuẩn.');
        continue;
      }

      // Stroke passed directional and positioning criteria
      correctStrokes++;
      feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Chuẩn hướng và thứ tự.');
    }

    // Missing strokes warning
    if (userCount < totalStandard) {
      final missing = totalStandard - userCount;
      feedbackList.add('Còn thiếu $missing nét so với chữ chuẩn ($userCount/$totalStandard nét).');
    } else if (userCount > totalStandard) {
      final extra = userCount - totalStandard;
      feedbackList.add('Thừa $extra nét so với số nét chuẩn của chữ.');
    }

    final accuracy = (correctStrokes / totalStandard).clamp(0.0, 1.0);
    final percent = (accuracy * 100).round();

    String verdict;
    if (percent == 100 && userCount == totalStandard) {
      verdict = isTracing
          ? 'Rất tốt! Bạn đã tô đúng 100% thứ tự nét bút thuận theo mẫu.'
          : 'Tuyệt vời! Bạn đã tự viết đúng hoàn toàn thứ tự nét chuẩn.';
    } else if (percent >= 70) {
      verdict = 'Khá tốt! Đạt $percent% độ chuẩn xác thứ tự nét. Chú ý các nét bị ngược chiều hoặc lệch vị trí.';
    } else {
      verdict = 'Cần luyện thêm: Đạt $percent% thứ tự nét. Hãy quan sát hoạt họa thứ tự nét trước khi viết lại.';
    }

    return WritingEvaluationResult(
      strokeOrderAccuracy: accuracy,
      correctStrokeCount: correctStrokes,
      totalStandardStrokes: totalStandard,
      userDrawnStrokesCount: userCount,
      isTracingMode: isTracing,
      strokeFeedbackList: feedbackList,
      overallVerdict: verdict,
      hasStandardStrokeData: true,
    );
  }
}
