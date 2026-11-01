import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/stroke_models.dart';
import 'hanzi_canvas_controller.dart';

/// Control toolbar for switching writing modes, adjusting stroke width,
/// and triggering undo, reset, replay, and evaluation actions.
class WritingToolbar extends StatelessWidget {
  final HanziCanvasController controller;
  final VoidCallback onEvaluate;
  final VoidCallback? onReplay;
  final VoidCallback? onNextCharacter;
  final bool hasStrokeData;

  const WritingToolbar({
    super.key,
    required this.controller,
    required this.onEvaluate,
    this.onReplay,
    this.onNextCharacter,
    this.hasStrokeData = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            // Row 1: Mode Switch & Stroke Width Presets
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // Mode Toggle
                SegmentedButton<WritingMode>(
                  segments: const [
                    ButtonSegment(
                      value: WritingMode.tracing,
                      label: Text('Tô mẫu'),
                      icon: Icon(Icons.edit_note_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: WritingMode.freeform,
                      label: Text('Tự viết'),
                      icon: Icon(Icons.gesture_rounded, size: 18),
                    ),
                  ],
                  selected: {controller.mode},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      controller.setWritingMode(set.first);
                    }
                  },
                ),

                // Stroke Width Picker Chips
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: StrokeWidthPreset.values.map((preset) {
                    final isSelected = controller.strokeWidth == preset.width;
                    return Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(preset.labelVi),
                        selected: isSelected,
                        onSelected: (_) => controller.setStrokeWidth(preset.width),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Row 2: Action Buttons (Undo, Reset, Replay, Evaluate)
            Row(
              children: [
                // Undo Button
                IconButton.outlined(
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Hoàn tác nét vừa vẽ',
                  onPressed: controller.canUndo ? controller.undo : null,
                ),
                const SizedBox(width: AppSpacing.xs),

                // Reset Button
                IconButton.outlined(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Xóa toàn bộ nét',
                  onPressed: controller.strokeCount > 0 ? controller.reset : null,
                ),
                const SizedBox(width: AppSpacing.xs),

                // Replay Button (if supported)
                if (onReplay != null) ...[
                  IconButton.outlined(
                    icon: const Icon(Icons.play_arrow_rounded),
                    tooltip: 'Xem hoạt họa thứ tự nét',
                    onPressed: hasStrokeData ? onReplay : null,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],

                // Evaluate Action Button
                Expanded(
                  child: HiButton(
                    text: 'Chấm điểm',
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    variant: HiButtonVariant.primary,
                    size: HiButtonSize.md,
                    isFullWidth: true,
                    onPressed: controller.strokeCount > 0 ? onEvaluate : null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
