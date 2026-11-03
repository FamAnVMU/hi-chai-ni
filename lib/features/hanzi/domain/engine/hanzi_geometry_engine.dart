import '../models/hanzi_models.dart';

/// Geometry and stroke recognition engine based on Hanzi Writer algorithms.
/// Matches user touch gestures against reference stroke medians,
/// detecting correct strokes, stroke order mistakes, backwards strokes,
/// and computing accuracy scores.
class HanziGeometryEngine {
  /// Distance threshold for start/end points in 1024 font coordinate space
  static const double startAndEndDistThreshold = 250.0;

  /// Maximum average distance from user points to median curve
  static const double avgDistThreshold = 350.0;

  /// Minimum relative length threshold
  static const double minLengthThreshold = 0.35;

  const HanziGeometryEngine();

  /// Converts a screen touch point into font coordinate space [0..1024, -124..900]
  static Point2D screenToFont(
    Point2D screenPoint, {
    required double width,
    required double height,
    double padding = 20.0,
  }) {
    final effectiveWidth = width - 2 * padding;
    final effectiveHeight = height - 2 * padding;
    final scale = (effectiveWidth < effectiveHeight ? effectiveWidth : effectiveHeight) / 1024.0;
    final xOffset = padding + (effectiveWidth - 1024.0 * scale) / 2.0;
    final yOffset = padding + (effectiveHeight - 1024.0 * scale) / 2.0;

    final fontX = (screenPoint.x - xOffset) / scale;
    final fontY = 900.0 - (screenPoint.y - yOffset) / scale;

    return Point2D(fontX, fontY);
  }

  /// Converts a font coordinate point into screen canvas coordinates
  static Point2D fontToScreen(
    Point2D fontPoint, {
    required double width,
    required double height,
    double padding = 20.0,
  }) {
    final effectiveWidth = width - 2 * padding;
    final effectiveHeight = height - 2 * padding;
    final scale = (effectiveWidth < effectiveHeight ? effectiveWidth : effectiveHeight) / 1024.0;
    final xOffset = padding + (effectiveWidth - 1024.0 * scale) / 2.0;
    final yOffset = padding + (effectiveHeight - 1024.0 * scale) / 2.0;

    final screenX = xOffset + fontPoint.x * scale;
    final screenY = yOffset + (900.0 - fontPoint.y) * scale;

    return Point2D(screenX, screenY);
  }

  /// Evaluates user drawn points against the expected stroke in a character
  static StrokeValidationResult validateStroke({
    required List<Point2D> userPoints,
    required HanziCharacter character,
    required int expectedStrokeIndex,
    double leniency = 1.0,
  }) {
    if (userPoints.length < 2) {
      return StrokeValidationResult.mismatch(strokeIndex: expectedStrokeIndex);
    }

    final cleanPoints = _stripDuplicates(userPoints);
    if (cleanPoints.length < 2) {
      return StrokeValidationResult.mismatch(strokeIndex: expectedStrokeIndex);
    }

    if (expectedStrokeIndex < 0 || expectedStrokeIndex >= character.medians.length) {
      return StrokeValidationResult.mismatch(strokeIndex: expectedStrokeIndex);
    }

    final targetMedian = character.medians[expectedStrokeIndex];
    if (targetMedian.length < 2) {
      return StrokeValidationResult.mismatch(strokeIndex: expectedStrokeIndex);
    }

    // 1. Check if drawn backwards
    if (_isDrawnBackwards(cleanPoints, targetMedian, leniency)) {
      return StrokeValidationResult.backwards(strokeIndex: expectedStrokeIndex);
    }

    // 2. Test match with target stroke
    final matchResult = _checkStrokeMatch(cleanPoints, targetMedian, leniency);
    if (matchResult.isMatch) {
      return StrokeValidationResult.correct(
        strokeIndex: expectedStrokeIndex,
        accuracy: matchResult.accuracy,
      );
    }

    // 3. Test if user accidentally drew a later stroke (wrong stroke order)
    for (int i = expectedStrokeIndex + 1; i < character.medians.length; i++) {
      final laterMedian = character.medians[i];
      if (laterMedian.length >= 2) {
        final laterMatch = _checkStrokeMatch(cleanPoints, laterMedian, leniency);
        if (laterMatch.isMatch && laterMatch.accuracy >= 65.0) {
          return StrokeValidationResult.wrongOrder(
            expectedIndex: expectedStrokeIndex,
            matchedIndex: i,
          );
        }
      }
    }

    return StrokeValidationResult.mismatch(strokeIndex: expectedStrokeIndex);
  }

  static _MatchScore _checkStrokeMatch(
    List<Point2D> points,
    List<Point2D> median,
    double leniency,
  ) {
    // 1. Start and end distance check
    final startDist = points.first.distanceTo(median.first);
    final endDist = points.last.distanceTo(median.last);

    final maxEndThresh = startAndEndDistThreshold * leniency;
    if (startDist > maxEndThresh || endDist > maxEndThresh) {
      return const _MatchScore(isMatch: false, accuracy: 0.0);
    }

    // 2. Length check
    final userLen = _curveLength(points);
    final medianLen = _curveLength(median);
    final lenRatio = (userLen + 25.0) / (medianLen + 25.0);
    if (lenRatio * leniency < minLengthThreshold) {
      return const _MatchScore(isMatch: false, accuracy: 0.0);
    }

    // 3. Direction match using cosine similarity
    if (!_directionMatches(points, median)) {
      return const _MatchScore(isMatch: false, accuracy: 0.0);
    }

    // 4. Average distance to median
    final avgDist = _averageDistanceToCurve(points, median);
    if (avgDist > avgDistThreshold * leniency) {
      return const _MatchScore(isMatch: false, accuracy: 0.0);
    }

    // Calculate accuracy percentage (0..100%)
    final distPenalty = (avgDist / avgDistThreshold) * 25.0;
    final startPenalty = (startDist / maxEndThresh) * 15.0;
    final endPenalty = (endDist / maxEndThresh) * 15.0;
    final rawScore = 100.0 - distPenalty - startPenalty - endPenalty;
    final accuracy = rawScore.clamp(55.0, 100.0);

    return _MatchScore(isMatch: true, accuracy: accuracy);
  }

  static bool _isDrawnBackwards(
    List<Point2D> points,
    List<Point2D> median,
    double leniency,
  ) {
    final reverseStartDist = points.first.distanceTo(median.last);
    final reverseEndDist = points.last.distanceTo(median.first);
    final thresh = startAndEndDistThreshold * leniency;

    if (reverseStartDist <= thresh && reverseEndDist <= thresh) {
      return true;
    }

    // Check reversed direction
    final reversedPoints = points.reversed.toList();
    if (_directionMatches(reversedPoints, median)) {
      final normalDirectionMatch = _directionMatches(points, median);
      if (!normalDirectionMatch) {
        return true;
      }
    }

    return false;
  }

  static bool _directionMatches(List<Point2D> points, List<Point2D> median) {
    final userVectors = _getEdgeVectors(points);
    final medianVectors = _getEdgeVectors(median);

    if (userVectors.isEmpty || medianVectors.isEmpty) return false;

    double totalMaxSimilarity = 0.0;
    for (final uVec in userVectors) {
      double maxSim = -1.0;
      for (final mVec in medianVectors) {
        final sim = _cosineSimilarity(uVec, mVec);
        if (sim > maxSim) {
          maxSim = sim;
        }
      }
      totalMaxSimilarity += maxSim;
    }

    final avgSim = totalMaxSimilarity / userVectors.length;
    return avgSim > 0.0; // Cosine similarity > 0 means generally pointing in same quadrant
  }

  static double _cosineSimilarity(Point2D a, Point2D b) {
    final dot = a.x * b.x + a.y * b.y;
    final magA = a.length;
    final magB = b.length;
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (magA * magB);
  }

  static List<Point2D> _getEdgeVectors(List<Point2D> points) {
    final vectors = <Point2D>[];
    for (int i = 0; i < points.length - 1; i++) {
      final diff = points[i + 1].subtract(points[i]);
      if (diff.length > 2.0) {
        vectors.add(diff);
      }
    }
    return vectors;
  }

  static double _curveLength(List<Point2D> points) {
    double len = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      len += points[i].distanceTo(points[i + 1]);
    }
    return len;
  }

  static double _averageDistanceToCurve(List<Point2D> points, List<Point2D> curve) {
    if (points.isEmpty || curve.isEmpty) return double.infinity;

    double totalDist = 0.0;
    for (final p in points) {
      double minDist = double.infinity;
      for (int i = 0; i < curve.length - 1; i++) {
        final dist = _pointToSegmentDistance(p, curve[i], curve[i + 1]);
        if (dist < minDist) {
          minDist = dist;
        }
      }
      totalDist += minDist;
    }

    return totalDist / points.length;
  }

  static double _pointToSegmentDistance(Point2D p, Point2D a, Point2D b) {
    final ab = b.subtract(a);
    final ap = p.subtract(a);
    final abLenSq = ab.x * ab.x + ab.y * ab.y;

    if (abLenSq == 0) return p.distanceTo(a);

    final t = ((ap.x * ab.x + ap.y * ab.y) / abLenSq).clamp(0.0, 1.0);
    final closestPoint = Point2D(a.x + t * ab.x, a.y + t * ab.y);
    return p.distanceTo(closestPoint);
  }

  static List<Point2D> _stripDuplicates(List<Point2D> points) {
    if (points.length < 2) return points;
    final deduped = <Point2D>[points.first];
    for (int i = 1; i < points.length; i++) {
      if (points[i].distanceTo(deduped.last) > 3.0) {
        deduped.add(points[i]);
      }
    }
    return deduped;
  }
}

class _MatchScore {
  final bool isMatch;
  final double accuracy;

  const _MatchScore({required this.isMatch, required this.accuracy});
}
