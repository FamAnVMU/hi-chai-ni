import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/stroke_models.dart';
import 'hanzi_canvas_controller.dart';
import 'hanzi_painter.dart';
import 'mizige_painter.dart';

/// Touch and stylus-responsive canvas for Chinese character practice.
/// Encapsulated with [RepaintBoundary] to guarantee 60-120fps performance
/// without causing full-screen rebuilds on pointer movements.
class HanziCanvas extends StatelessWidget {
  final HanziCanvasController controller;
  final String? character;
  final HanziStrokeData? strokeData;
  final int? highlightedStrokeOrder;
  final double size;

  const HanziCanvas({
    super.key,
    required this.controller,
    this.character,
    this.strokeData,
    this.highlightedStrokeOrder,
    this.size = 320.0,
  });

  @override
  Widget build(BuildContext context) {
    controller.setCanvasSize(Size(size, size));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Semantics(
        label: 'Khung lưới tập viết chữ Hán ${character ?? ''}. Nhấn và rê để vẽ nét chữ.',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkForestSurface : AppColors.offWhite,
            borderRadius: AppRadius.borderMd,
            boxShadow: AppElevation.shadowMid(theme.brightness),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: Stack(
              children: [
                // 1. Static Calligraphy Grid Layer (Mizige)
                Positioned.fill(
                  child: CustomPaint(
                    painter: MizigePainter(
                      borderColor: isDark
                          ? AppColors.darkForestBorder
                          : theme.colorScheme.outlineVariant,
                      guidelineColor: isDark
                          ? AppColors.darkForestBorder.withAlpha(80)
                          : theme.colorScheme.outlineVariant.withAlpha(90),
                    ),
                  ),
                ),

                // 2. Interactive Gesture Listener & Stroke Layer
                Positioned.fill(
                  child: Listener(
                    onPointerDown: controller.onPointerDown,
                    onPointerMove: controller.onPointerMove,
                    onPointerUp: controller.onPointerUp,
                    onPointerCancel: controller.onPointerCancel,
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: HanziPainter(
                              strokes: controller.strokes,
                              activeStroke: controller.activeStroke,
                              character: character,
                              strokeData: strokeData,
                              mode: controller.mode,
                              highlightedStrokeOrder: highlightedStrokeOrder,
                              watermarkColor: isDark
                                  ? AppColors.limeGreen.withAlpha(45)
                                  : AppColors.limeGreen.withAlpha(70),
                              highlightStrokeColor: AppColors.limeGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
