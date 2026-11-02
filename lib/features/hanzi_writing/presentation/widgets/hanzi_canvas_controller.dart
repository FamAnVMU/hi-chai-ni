import 'package:flutter/material.dart';
import '../../domain/models/stroke_models.dart';

/// Highly optimized controller managing stroke collection, touch/stylus events,
/// undo/reset buffers, and isolated canvas repainting.
class HanziCanvasController extends ChangeNotifier {
  final List<DrawnStroke> _strokes = [];
  DrawnStroke? _activeStroke;
  double _strokeWidth = 7.0;
  Color _strokeColor = const Color(0xFF121811);
  WritingMode _mode = WritingMode.tracing;
  Size _canvasSize = const Size(320.0, 320.0);

  List<DrawnStroke> get strokes => List.unmodifiable(_strokes);
  DrawnStroke? get activeStroke => _activeStroke;
  double get strokeWidth => _strokeWidth;
  Color get strokeColor => _strokeColor;
  WritingMode get mode => _mode;
  Size get canvasSize => _canvasSize;

  bool get canUndo => _strokes.isNotEmpty;
  int get strokeCount => _strokes.length;

  void setCanvasSize(Size size) {
    if (_canvasSize != size) {
      _canvasSize = size;
    }
  }

  void setStrokeWidth(double width) {
    if (_strokeWidth != width) {
      _strokeWidth = width;
      notifyListeners();
    }
  }

  void setStrokeColor(Color color) {
    if (_strokeColor != color) {
      _strokeColor = color;
      notifyListeners();
    }
  }

  void setWritingMode(WritingMode newMode) {
    if (_mode != newMode) {
      _mode = newMode;
      notifyListeners();
    }
  }

  void onPointerDown(PointerDownEvent event) {
    final point = StrokePoint(
      offset: event.localPosition,
      pressure: event.pressure.clamp(0.2, 2.0),
      timestamp: DateTime.now(),
    );

    _activeStroke = DrawnStroke(
      points: [point],
      color: _strokeColor,
      baseStrokeWidth: _strokeWidth,
    );

    notifyListeners();
  }

  void onPointerMove(PointerMoveEvent event) {
    if (_activeStroke == null) return;

    final newOffset = event.localPosition;
    final lastPoint = _activeStroke!.points.last;

    // Filter out micro-jitter points (< 1.5px) for smoother curves and 60-120fps performance
    if ((newOffset - lastPoint.offset).distance < 1.5) {
      return;
    }

    final point = StrokePoint(
      offset: newOffset,
      pressure: event.pressure.clamp(0.2, 2.0),
      timestamp: DateTime.now(),
    );

    _activeStroke!.points.add(point);
    notifyListeners();
  }

  void onPointerUp(PointerUpEvent event) {
    if (_activeStroke == null) return;

    final point = StrokePoint(
      offset: event.localPosition,
      pressure: event.pressure.clamp(0.2, 2.0),
      timestamp: DateTime.now(),
    );

    _activeStroke!.points.add(point);

    if (_activeStroke!.points.isNotEmpty) {
      _strokes.add(_activeStroke!);
    }

    _activeStroke = null;
    notifyListeners();
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (_activeStroke != null) {
      if (_activeStroke!.points.length > 2) {
        _strokes.add(_activeStroke!);
      }
      _activeStroke = null;
      notifyListeners();
    }
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      notifyListeners();
    }
  }

  void reset() {
    if (_strokes.isNotEmpty || _activeStroke != null) {
      _strokes.clear();
      _activeStroke = null;
      notifyListeners();
    }
  }

  void restoreStrokes(List<DrawnStroke> restoredStrokes) {
    _strokes.clear();
    _strokes.addAll(restoredStrokes);
    _activeStroke = null;
    notifyListeners();
  }
}
