import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Atomic point captured from pointer/stylus events.
class StrokePoint {
  final Offset offset;
  final double pressure;
  final DateTime timestamp;

  const StrokePoint({
    required this.offset,
    this.pressure = 1.0,
    required this.timestamp,
  });

  double get x => offset.dx;
  double get y => offset.dy;

  Map<String, dynamic> toMap() => {
        'x': offset.dx,
        'y': offset.dy,
        'p': pressure,
        't': timestamp.millisecondsSinceEpoch,
      };

  factory StrokePoint.fromMap(Map<String, dynamic> map) => StrokePoint(
        offset: Offset(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        ),
        pressure: (map['p'] as num?)?.toDouble() ?? 1.0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['t'] as num).toInt(),
        ),
      );
}

/// A continuous stroke drawn by the user from pen-down to pen-up.
class DrawnStroke {
  final List<StrokePoint> points;
  final Color color;
  final double baseStrokeWidth;

  const DrawnStroke({
    required this.points,
    this.color = const Color(0xFF1A2418),
    this.baseStrokeWidth = 7.0,
  });

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  StrokePoint? get startPoint => isEmpty ? null : points.first;
  StrokePoint? get endPoint => isEmpty ? null : points.last;

  /// Direction vector from start to end point.
  Offset get directionVector {
    if (points.length < 2) return Offset.zero;
    return endPoint!.offset - startPoint!.offset;
  }

  /// Total Euclidean length of the drawn trajectory.
  double get totalLength {
    if (points.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      sum += (points[i + 1].offset - points[i].offset).distance;
    }
    return sum;
  }

  /// Angle in radians of the primary stroke direction.
  double get angleRadians {
    final v = directionVector;
    return math.atan2(v.dy, v.dx);
  }

  /// Normalizes all stroke coordinates relative to bounding canvas size.
  DrawnStroke normalized(Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return this;
    final normalizedPoints = points.map((p) {
      return StrokePoint(
        offset: Offset(p.x / canvasSize.width, p.y / canvasSize.height),
        pressure: p.pressure,
        timestamp: p.timestamp,
      );
    }).toList();

    return DrawnStroke(
      points: normalizedPoints,
      color: color,
      baseStrokeWidth: baseStrokeWidth,
    );
  }
}

/// The fundamental types of Chinese character strokes (Vĩnh Tự Bát Pháp / 永字八法).
enum StrokeType {
  heng(nameVi: 'Nét Ngang (横)', pinyin: 'héng'),
  shu(nameVi: 'Nét Sổ (竖)', pinyin: 'shù'),
  pie(nameVi: 'Nét Phẩy (撇)', pinyin: 'piě'),
  na(nameVi: 'Nét Mác (捺)', pinyin: 'nà'),
  dian(nameVi: 'Nét Chấm (点)', pinyin: 'diǎn'),
  ti(nameVi: 'Nét Hất (提)', pinyin: 'tí'),
  zhe(nameVi: 'Nét Gập (折)', pinyin: 'zhé'),
  gou(nameVi: 'Nét Móc (钩)', pinyin: 'gōu');

  final String nameVi;
  final String pinyin;

  const StrokeType({required this.nameVi, required this.pinyin});
}

/// Standard verified stroke in canonical Chinese stroke order.
class StandardStroke {
  final int order;
  final StrokeType type;
  final String nameVi;

  /// Start point in normalized coordinates `[0, 1] x [0, 1]`.
  final Offset normalizedStart;

  /// End point in normalized coordinates `[0, 1] x [0, 1]`.
  final Offset normalizedEnd;

  /// Optional intermediate spline control points for compound strokes (e.g. 横折钩).
  final List<Offset> controlPoints;

  const StandardStroke({
    required this.order,
    required this.type,
    required this.nameVi,
    required this.normalizedStart,
    required this.normalizedEnd,
    this.controlPoints = const [],
  });

  /// Expected direction vector in normalized coordinate space.
  Offset get expectedVector => normalizedEnd - normalizedStart;

  /// Expected angle in radians.
  double get expectedAngle => math.atan2(expectedVector.dy, expectedVector.dx);
}

/// Complete verified stroke order specification for a single Hanzi.
class HanziStrokeData {
  final String character;
  final int totalStrokes;
  final List<StandardStroke> strokes;
  final String? radical;
  final String? pinyin;
  final String? meaningVi;
  final bool isVerified;

  const HanziStrokeData({
    required this.character,
    required this.totalStrokes,
    required this.strokes,
    this.radical,
    this.pinyin,
    this.meaningVi,
    this.isVerified = true,
  });

  StandardStroke? getStroke(int index) {
    if (index >= 0 && index < strokes.length) return strokes[index];
    return null;
  }
}

/// Mode of practicing Hanzi handwriting.
enum WritingMode {
  tracing(labelVi: 'Tô theo mẫu'),
  freeform(labelVi: 'Tự viết');

  final String labelVi;
  const WritingMode({required this.labelVi});
}

/// Pen stroke width presets.
enum StrokeWidthPreset {
  thin(width: 4.0, labelVi: 'Mảnh'),
  medium(width: 7.0, labelVi: 'Vừa'),
  thick(width: 11.0, labelVi: 'Đậm');

  final double width;
  final String labelVi;
  const StrokeWidthPreset({required this.width, required this.labelVi});
}

/// Objective evaluation of user handwriting against standard stroke order.
class WritingEvaluationResult {
  final double strokeOrderAccuracy; // 0.0 to 1.0
  final int correctStrokeCount;
  final int totalStandardStrokes;
  final int userDrawnStrokesCount;
  final bool isTracingMode;
  final List<String> strokeFeedbackList;
  final String overallVerdict;
  final bool hasStandardStrokeData;

  const WritingEvaluationResult({
    required this.strokeOrderAccuracy,
    required this.correctStrokeCount,
    required this.totalStandardStrokes,
    required this.userDrawnStrokesCount,
    required this.isTracingMode,
    required this.strokeFeedbackList,
    required this.overallVerdict,
    this.hasStandardStrokeData = true,
  });

  int get scorePercent => (strokeOrderAccuracy * 100).round().clamp(0, 100);

  bool get isPassed => scorePercent >= 70;
}
