import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Clean Modern Card providing prominent, direct access to the learner's current curriculum lesson.
/// Replaces HomeSrsDueCard at Slot 2 on the Home Screen.
class HomeLessonAccessCard extends StatelessWidget {
  final RoadmapProgress? roadmap;
  final VoidCallback onNavigateLearning;

  const HomeLessonAccessCard({
    super.key,
    required this.roadmap,
    required this.onNavigateLearning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final rm = roadmap;
    final hasStarted = rm != null && rm.learnedVocabCount > 0;
    final lessonTitle = rm?.nextLessonTitle ?? 'Bài 1: Chào hỏi & Pinyin cơ bản';
    final lessonSnippet = rm?.nextLessonSnippet ?? '你[nǐ]好[hǎo]，我[wǒ]叫[jiào]李[lǐ]华[huá]。';
    final progressString = rm?.progressPercentageString ?? '0%';
    final progressRatio = rm?.progressRatio ?? 0.0;
    final vocabProgressText = rm != null
        ? '${rm.learnedVocabCount}/${rm.totalVocabCount} từ'
        : '0/150 từ';

    return HiCard(
      borderColor: isDark
          ? AppColors.accentBlue.withAlpha(120)
          : AppColors.primaryBlue.withAlpha(120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Chip
          Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: isDark ? AppColors.accentBlue : AppColors.primaryBlueDark,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tiếp tục bài học',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              HiChip(
                label: vocabProgressText,
                status: hasStarted ? HiChipStatus.neutral : HiChipStatus.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Current or Next Lesson Title
          Text(
            lessonTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Lesson snippet with ruby pinyin
          RubyText.fromAnnotatedString(
            annotatedText: lessonSnippet,
            showPinyin: true,
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress label and ratio
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiến độ cấp độ: $progressString',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              if (rm != null && rm.masteredVocabCount > 0)
                Text(
                  '${rm.masteredVocabCount} từ thành thạo',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.accentBlue : AppColors.primaryBlueDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          HiLinearProgress(value: progressRatio),
          const SizedBox(height: AppSpacing.md),

          // Primary Call-to-Action Button
          HiButton(
            text: hasStarted ? 'Vào học ngay' : 'Bắt đầu Bài 1 – HSK 1',
            icon: const Icon(Icons.play_arrow_rounded),
            variant: HiButtonVariant.primary,
            size: HiButtonSize.md,
            isFullWidth: true,
            onPressed: onNavigateLearning,
          ),
        ],
      ),
    );
  }
}
