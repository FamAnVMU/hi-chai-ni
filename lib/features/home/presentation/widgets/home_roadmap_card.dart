import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Card showing the learner's active HSK roadmap progress and next lesson snippet.
class HomeRoadmapCard extends StatelessWidget {
  final RoadmapProgress roadmap;
  final VoidCallback onContinueLesson;

  const HomeRoadmapCard({
    super.key,
    required this.roadmap,
    required this.onContinueLesson,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_rounded,
                color: AppColors.limeGreen,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  roadmap.levelTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              HiChip(
                label: '${roadmap.learnedVocabCount}/${roadmap.totalVocabCount} từ',
                status: HiChipStatus.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            roadmap.nextLessonTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          RubyText.fromAnnotatedString(
            annotatedText: roadmap.nextLessonSnippet,
            showPinyin: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiến độ cấp độ: ${roadmap.progressPercentageString}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (roadmap.masteredVocabCount > 0)
                Text(
                  '${roadmap.masteredVocabCount} từ thành thạo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.limeGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          HiLinearProgress(value: roadmap.progressRatio),
          const SizedBox(height: AppSpacing.md),
          HiButton(
            text: roadmap.learnedVocabCount > 0 ? 'Tiếp tục bài học' : 'Bắt đầu bài học đầu tiên',
            icon: const Icon(Icons.arrow_forward_rounded),
            variant: HiButtonVariant.secondary,
            size: HiButtonSize.md,
            onPressed: onContinueLesson,
          ),
        ],
      ),
    );
  }
}
