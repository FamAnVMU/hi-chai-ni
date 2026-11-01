import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/pronunciation_models.dart';

/// Card rendering objective speech recognition and acoustic analysis results.
class PronunciationResultCard extends StatelessWidget {
  final PronunciationAssessmentResult result;
  final VoidCallback? onPlayUserAudio;
  final VoidCallback? onDeleteAudio;
  final bool isPlayingAudio;

  const PronunciationResultCard({
    super.key,
    required this.result,
    this.onPlayUserAudio,
    this.onDeleteAudio,
    this.isPlayingAudio = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isRecognized = result.isRecognizedAccurately;

    return HiCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Header & Confidence Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isRecognized ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: isRecognized ? AppColors.limeGreen : Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Kết Quả Phân Tích',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              HiChip(
                label: 'Độ tin cậy: ${_formatConfidence(result.confidence)}',
                status: _getConfidenceStatus(result.confidence),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: Recognized Transcript Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkForestSurface : AppColors.offWhite,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transcript nhận dạng (ASR):',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      result.recognizedTranscript ?? '(Không phát hiện giọng nói)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isRecognized ? theme.colorScheme.onSurface : theme.colorScheme.error,
                      ),
                    ),
                    if (result.overallScore != null)
                      Text(
                        'Điểm ASR: ${(result.overallScore! * 100).toInt()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.limeGreen,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 3: Acoustic Tone & Phoneme Breakdown (Academic Honesty)
          if (result.isAcousticallyAnalyzed) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Độ chuẩn thanh điệu',
                    value: '${((result.toneAccuracy ?? 0) * 100).toInt()}%',
                    icon: Icons.graphic_eq_rounded,
                    color: AppColors.limeGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Âm đầu & Vận mẫu',
                    value: '${((result.initialFinalAccuracy ?? 0) * 100).toInt()}%',
                    icon: Icons.record_voice_over_rounded,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            // Explicit disclaimer when acoustic model is not active
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: Colors.amber.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Lưu ý: Mô hình "${result.providerId}" chỉ thực hiện nhận dạng văn bản ASR. Chưa hỗ trợ bộ phân tích âm học thanh điệu (Acoustic Tone Analysis).',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Row 4: Detailed Feedback List
          Text(
            'Nhận xét chi tiết:',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...result.feedbackList.map((fb) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded, size: 18, color: AppColors.limeGreen),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(fb, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // Row 5: Action Controls (Replay user audio & Delete audio)
          Row(
            children: [
              if (result.audioLocalPath != null) ...[
                Expanded(
                  child: HiButton(
                    text: isPlayingAudio ? 'Đang phát...' : 'Nghe lại bản thu',
                    icon: Icon(isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    variant: HiButtonVariant.secondary,
                    size: HiButtonSize.sm,
                    onPressed: onPlayUserAudio,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.outlined(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Xóa bản thu âm',
                  onPressed: onDeleteAudio,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatConfidence(PronunciationConfidence c) {
    switch (c) {
      case PronunciationConfidence.high:
        return 'Cao';
      case PronunciationConfidence.medium:
        return 'Vừa';
      case PronunciationConfidence.low:
        return 'Thấp';
    }
  }

  HiChipStatus _getConfidenceStatus(PronunciationConfidence c) {
    switch (c) {
      case PronunciationConfidence.high:
        return HiChipStatus.success;
      case PronunciationConfidence.medium:
        return HiChipStatus.info;
      case PronunciationConfidence.low:
        return HiChipStatus.warning;
    }
  }
}
