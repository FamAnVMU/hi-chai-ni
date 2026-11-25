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

      if (cosSimilarity < 0.70) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Hướng nét bị lệch so với chuẩn.');
        continue;
      }

      // 2. Start & end point proximity in normalized canvas
      final startDist = (userStroke.startPoint!.offset - stdStroke.normalizedStart).distance;
      final endDist = (userStroke.endPoint!.offset - stdStroke.normalizedEnd).distance;

      // Allow slightly wider tolerance in freeform mode than tracing mode
      final endpointTolerance = isTracing ? 0.35 : 0.45;

      if (startDist > endpointTolerance) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Điểm đặt bút bị lệch so với vị trí chuẩn.');
        continue;
      }

      if (endDist > endpointTolerance) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Điểm kết thúc nét chưa đúng vị trí chuẩn.');
        continue;
      }

      // 3. Resampled N=32 trajectory comparison through control points (catches wrong bend shapes)
      final referencePolyline = <Offset>[
        stdStroke.normalizedStart,
        ...stdStroke.controlPoints,
        stdStroke.normalizedEnd,
      ];
      final resampledUser = _resamplePolyline(
        userStroke.points.map((p) => p.offset).toList(),
        32,
      );
      final resampledRef = _resamplePolyline(referencePolyline, 32);
      final avgPathDist = _meanPointwiseDistance(resampledUser, resampledRef);
      final pathTolerance = isTracing ? 0.25 : 0.35;

      if (avgPathDist > pathTolerance) {
        feedbackList.add('Nét ${i + 1} (${stdStroke.nameVi}): Đường đi hoặc độ gập của nét chưa khớp mẫu.');
        continue;
      }

      // Stroke passed directional, endpoint, and trajectory criteria
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

    final totalCompared = math.max(totalStandard, userCount);
    final accuracy = (correctStrokes / totalCompared).clamp(0.0, 1.0);
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

  /// Resamples an open polyline into [n] equidistant points along its arc length.
  static List<Offset> _resamplePolyline(List<Offset> points, int n) {
    if (points.isEmpty || n <= 1) return points;
    if (points.length == 1) return List<Offset>.filled(n, points.first);

    final cumulative = <double>[0.0];
    double totalLen = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalLen += (points[i + 1] - points[i]).distance;
      cumulative.add(totalLen);
    }

    if (totalLen <= 1e-6) {
      return List<Offset>.filled(n, points.first);
    }

    final resampled = <Offset>[];
    final step = totalLen / (n - 1);
    int segIdx = 0;

    for (int k = 0; k < n; k++) {
      final targetDist = k == n - 1 ? totalLen : k * step;
      while (segIdx < cumulative.length - 2 && cumulative[segIdx + 1] < targetDist) {
        segIdx++;
      }
      final segStartDist = cumulative[segIdx];
      final segEndDist = cumulative[segIdx + 1];
      final segLen = segEndDist - segStartDist;
      final t = segLen <= 1e-6 ? 0.0 : ((targetDist - segStartDist) / segLen).clamp(0.0, 1.0);
      resampled.add(Offset.lerp(points[segIdx], points[segIdx + 1], t)!);
    }

    return resampled;
  }

  static double _meanPointwiseDistance(List<Offset> a, List<Offset> b) {
    final len = math.min(a.length, b.length);
    if (len == 0) return 1.0;
    double sum = 0.0;
    for (int i = 0; i < len; i++) {
      sum += (a[i] - b[i]).distance;
    }
    return sum / len;
  }
}
