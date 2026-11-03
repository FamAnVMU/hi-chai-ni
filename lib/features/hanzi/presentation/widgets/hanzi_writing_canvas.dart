import 'package:flutter/material.dart';
import '../../domain/engine/hanzi_geometry_engine.dart';
import '../../domain/models/hanzi_models.dart';
import '../painters/hanzi_character_painter.dart';
import '../painters/user_drawing_painter.dart';

/// Interactive writing canvas widget providing touch recognition,
/// stroke animation, and realtime feedback for Chinese characters.
class HanziWritingCanvas extends StatefulWidget {
  final HanziCharacter? character;
  final int completedStrokesCount;
  final int? activeStrokeIndex;
  final double animationProgress;
  final bool showOutline;
  final bool showStrokeNumbers;
  final bool isInteractive;
  final WritingGridType gridType;
  final bool showHint;
  final void Function(StrokeValidationResult result)? onStrokeCompleted;
  final VoidCallback? onDrawingStarted;

  const HanziWritingCanvas({
    super.key,
    required this.character,
    this.completedStrokesCount = 0,
    this.activeStrokeIndex,
    this.animationProgress = 1.0,
    this.showOutline = true,
    this.showStrokeNumbers = false,
    this.isInteractive = true,
    this.gridType = WritingGridType.miZiGe,
    this.showHint = false,
    this.onStrokeCompleted,
    this.onDrawingStarted,
  });

  @override
  State<HanziWritingCanvas> createState() => _HanziWritingCanvasState();
}

class _HanziWritingCanvasState extends State<HanziWritingCanvas> {
  final List<Point2D> _userPoints = [];
  Color _strokeColor = const Color(0xFF2563EB);

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    if (!widget.isInteractive || widget.character == null) return;
    setState(() {
      _userPoints.clear();
      _strokeColor = const Color(0xFF2563EB);
      _userPoints.add(Point2D(details.localPosition.dx, details.localPosition.dy));
    });
    widget.onDrawingStarted?.call();
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (!widget.isInteractive || widget.character == null) return;
    setState(() {
      _userPoints.add(Point2D(details.localPosition.dx, details.localPosition.dy));
    });
  }

  void _onPanEnd(DragEndDetails details, Size canvasSize) {
    if (!widget.isInteractive || widget.character == null || _userPoints.isEmpty) return;

    // Convert user screen touch points to 1024 font coordinate space
    final fontPoints = _userPoints.map((p) {
      return HanziGeometryEngine.screenToFont(
        p,
        width: canvasSize.width,
        height: canvasSize.height,
        padding: 24.0,
      );
    }).toList();

    // Validate stroke against current expected stroke
    final result = HanziGeometryEngine.validateStroke(
      userPoints: fontPoints,
      character: widget.character!,
      expectedStrokeIndex: widget.completedStrokesCount,
    );

    if (result.isMatch) {
      setState(() {
        _strokeColor = const Color(0xFF10B981); // Emerald green for success
      });
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() {
            _userPoints.clear();
          });
          widget.onStrokeCompleted?.call(result);
        }
      });
    } else {
      setState(() {
        _strokeColor = const Color(0xFFEF4444); // Red for mistake
      });
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) {
          setState(() {
            _userPoints.clear();
          });
          widget.onStrokeCompleted?.call(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final canvasSize = Size(dimension, dimension);

        return Center(
          child: Container(
            width: dimension,
            height: dimension,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              onPanStart: (d) => _onPanStart(d, canvasSize),
              onPanUpdate: (d) => _onPanUpdate(d, canvasSize),
              onPanEnd: (d) => _onPanEnd(d, canvasSize),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  // 1. Character outline & completed strokes painter
                  CustomPaint(
                    size: canvasSize,
                    painter: HanziCharacterPainter(
                      character: widget.character,
                      completedStrokesCount: widget.completedStrokesCount,
                      activeStrokeIndex: widget.activeStrokeIndex,
                      animationProgress: widget.animationProgress,
                      showOutline: widget.showOutline,
                      showStrokeNumbers: widget.showStrokeNumbers,
                      gridType: widget.gridType,
                    ),
                  ),

                  // 2. Active hint highlighting for current stroke
                  if (widget.showHint &&
                      widget.character != null &&
                      widget.completedStrokesCount < widget.character!.strokes.length)
                    CustomPaint(
                      size: canvasSize,
                      painter: HanziCharacterPainter(
                        character: widget.character,
                        completedStrokesCount: 0,
                        activeStrokeIndex: widget.completedStrokesCount,
                        animationProgress: 1.0,
                        showOutline: false,
                        showStrokeNumbers: false,
                        gridType: WritingGridType.none,
                        activeStrokeColor: const Color(0xFFF59E0B).withAlpha(180), // Amber glow
                      ),
                    ),

                  // 3. User's live calligraphy ink painter
                  CustomPaint(
                    size: canvasSize,
                    painter: UserDrawingPainter(
                      points: _userPoints,
                      strokeColor: _strokeColor,
                      strokeWidth: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
