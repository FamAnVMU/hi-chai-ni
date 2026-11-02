import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

class LessonWarmupView extends StatelessWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final VoidCallback onStart;

  const LessonWarmupView({
    super.key,
    required this.lesson,
    this.segment,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final introText = (segment?.contentPayload?['intro'] as String?) ??
        'Chào mừng bạn đến với bài học "${lesson.titleZh}". Hãy cùng khởi động và nắm vững kiến thức nhé!';

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.limeGreen.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 56,
                color: AppColors.limeGreenDark,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Khởi Động Bài Học',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.limeGreenDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${lesson.titleZh} • ${lesson.pinyin}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          HiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: AppColors.limeGreen),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Mục tiêu học tập',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  introText,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20, color: AppColors.limeGreenDark),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Thời gian học dự kiến: ${lesson.estimatedMinutes} phút',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          HiButton(
            text: 'Bắt đầu học từ vựng',
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            isFullWidth: true,
            size: HiButtonSize.lg,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
