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
    if (segment?.contentPayload == null) {
      debugPrint(
        '[CurriculumUI] Warmup content payload missing: '
        'lessonId=${lesson.id}, segmentId=${segment?.id}, refId=${segment?.contentRefId}',
      );
    }
    final introText = (segment?.contentPayload?['intro'] as String?) ??
        (segment?.contentPayload?['objective'] as String?) ??
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
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 52,
                color: AppColors.primaryBlueDark,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Khởi Động Bài Học',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${lesson.titleZh} • ${lesson.pinyin}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          HiCard(
            backgroundColor: AppColors.cardBackground,
            borderColor: AppColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_rounded, color: AppColors.primaryBlueDark, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Mục tiêu học tập',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  introText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 20, color: AppColors.primaryBlueDark),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Thời gian học dự kiến: ${lesson.estimatedMinutes} phút',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
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
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            isFullWidth: true,
            size: HiButtonSize.lg,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
