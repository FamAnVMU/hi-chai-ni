import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/shadowing_models.dart';

/// Card rendering visual timeline comparison between native model speech and user recording.
class ShadowingTimelineCard extends StatelessWidget {
  final ShadowingAssessmentResult result;
  final VoidCallback? onPlayUserAudio;
  final VoidCallback? onDeleteAudio;
  final bool isPlayingAudio;

  const ShadowingTimelineCard({
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

    final targetSec = (result.targetDurationMs / 1000).toStringAsFixed(1);
    final userSec = (result.userDurationMs / 1000).toStringAsFixed(1);

    final isOptimal = result.pacingRatio >= 0.85 && result.pacingRatio <= 1.15;

    return HiCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Header & Pacing Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOptimal ? Icons.speed_rounded : Icons.av_timer_rounded,
                    color: isOptimal ? AppColors.primaryBlueDark : Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Đối Chiếu Nhịp Độ & Timeline',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              HiChip(
                label: 'Tỷ lệ: ${result.pacingRatio}x',
                status: isOptimal ? HiChipStatus.success : HiChipStatus.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 2: Dual Timeline Comparison Bars
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardBackground : AppColors.cardBackground,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                // 1. Native Model Timeline Bar
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Bản mẫu:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.borderFull,
                        child: LinearProgressIndicator(
                          value: 1.0,
                          minHeight: 10,
                          backgroundColor: theme.colorScheme.outlineVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${targetSec}s',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // 2. User Speech Timeline Bar
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Bạn nói:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.borderFull,
                        child: LinearProgressIndicator(
                          value: (result.pacingRatio / 1.5).clamp(0.05, 1.0),
                          minHeight: 10,
                          backgroundColor: theme.colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOptimal ? AppColors.primaryBlueDark : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${userSec}s',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 3: Verdict & Metrics
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: (isOptimal ? AppColors.primaryBlueDark : Colors.orangeAccent).withAlpha(20),
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: (isOptimal ? AppColors.primaryBlueDark : Colors.orangeAccent).withAlpha(80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOptimal ? Icons.thumb_up_alt_rounded : Icons.tune_rounded,
                  size: 20,
                  color: isOptimal ? AppColors.primaryBlueDark : Colors.orangeAccent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    result.pacingVerdict,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOptimal ? theme.colorScheme.onSurface : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Row 4: Metrics Row (Timeline Match & Fluency Index)
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  theme,
                  label: 'Trùng khớp Timeline',
                  value: '${result.timelineMatchPercent.toInt()}%',
                  color: AppColors.primaryBlueDark,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildMetric(
                  theme,
                  label: 'Độ trôi chảy (Fluency)',
                  value: '${(result.fluencyIndex * 100).toInt()}%',
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 5: Academic Honesty Disclaimer
          Text(
            result.disclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Row 6: Audio Actions (Replay & Delete)
          if (result.userAudioPath != null) ...[
            Row(
              children: [
                Expanded(
                  child: HiButton(
                    text: isPlayingAudio ? 'Đang phát...' : 'Nghe lại giọng nói',
                    icon: Icon(isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    variant: HiButtonVariant.secondary,
                    size: HiButtonSize.sm,
                    onPressed: onPlayUserAudio,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.outlined(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Xóa bản thu âm Shadowing',
                  onPressed: onDeleteAudio,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(
    ThemeData theme, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
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
    );
  }
}
