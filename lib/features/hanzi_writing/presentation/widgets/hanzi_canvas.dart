import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/stroke_models.dart';
import 'hanzi_canvas_controller.dart';
import 'hanzi_painter.dart';
import 'mizige_painter.dart';

class HanziCanvas extends StatelessWidget {
  final HanziCanvasController controller;
  final String? character;
  final HanziStrokeData? strokeData;
  final int? highlightedStrokeOrder;
  final double size;
  final VoidCallback? onStepReplay;

  const HanziCanvas({
    super.key,
    required this.controller,
    this.character,
    this.strokeData,
    this.highlightedStrokeOrder,
    this.size = 320.0,
    this.onStepReplay,
  });

  @override
  Widget build(BuildContext context) {
    controller.setCanvasSize(Size(size, size));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final modeStr =
              controller.mode == WritingMode.tracing ? 'Tô mẫu' : 'Tự viết';
          final strokeCount = controller.strokes.length;
          final totalStrokesStr = strokeData != null
              ? ' trên tổng số ${strokeData!.totalStrokes} nét chuẩn'
              : '';

          return Semantics(
            container: true,
            label: 'Khung lưới tập viết chữ Hán ${character ?? ''}.',
            value:
                'Chữ ${character ?? ''}${strokeData?.pinyin != null ? ', phát âm ${strokeData!.pinyin}' : ''}. Chế độ: $modeStr. Đã viết $strokeCount nét$totalStrokesStr.',
            hint:
                'Chạm và rê để vẽ nét chữ trên ô lưới Mễ tự cách. Sử dụng các thao tác trợ năng hoặc các nút công cụ bên dưới để hoàn tác nét hoặc xóa toàn bộ bảng.',
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Xóa toàn bộ nét'): () {
                controller.reset();
              },
              const CustomSemanticsAction(label: 'Hoàn tác nét vừa vẽ'): () {
                if (controller.canUndo) {
                  controller.undo();
                }
              },
              if (onStepReplay != null)
                const CustomSemanticsAction(label: 'Xem mẫu nét tiếp theo'): () {
                  onStepReplay!();
                },
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardBackground : AppColors.cardBackground,
                borderRadius: AppRadius.borderMd,
                boxShadow: AppElevation.shadowMid(theme.brightness),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: Stack(
                  children: [
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
                    Positioned.fill(
                      child: Listener(
                        onPointerDown: controller.onPointerDown,
                        onPointerMove: controller.onPointerMove,
                        onPointerUp: controller.onPointerUp,
                        onPointerCancel: controller.onPointerCancel,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: HanziPainter(
                              strokes: controller.strokes,
                              activeStroke: controller.activeStroke,
                              character: character,
                              strokeData: strokeData,
                              mode: controller.mode,
                              highlightedStrokeOrder: highlightedStrokeOrder,
                              watermarkColor: isDark
                                  ? AppColors.primaryBlueDark.withAlpha(45)
                                  : AppColors.primaryBlueDark.withAlpha(70),
                              highlightStrokeColor: AppColors.primaryBlueDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
