import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

/// Celebratory Milestone View displayed when a learner completes a lesson.
///
/// Highlights:
/// - Celebratory icon & energetic title
/// - 2-column metrics block (+25 XP badge & Streak flame)
/// - Green status banner announcing the unlocked next lesson
/// - Primary action button "TIẾP TỤC HỌC ➔" triggering `onContinue`
class LessonCelebrationView extends StatelessWidget {
  final CurriculumLesson? lesson;
  final int xpGained;
  final int streakDays;
  final double? accuracyRate;
  final String? nextLessonTitle;
  final VoidCallback onContinue;
  final VoidCallback? onReviewLesson;

  const LessonCelebrationView({
    super.key,
    this.lesson,
    this.xpGained = 25,
    this.streakDays = 3,
    this.accuracyRate,
    this.nextLessonTitle,
    required this.onContinue,
    this.onReviewLesson,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveNextTitle = nextLessonTitle ?? 'Bài tiếp theo';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0.85, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Celebratory Trophy Badge
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFFF7D6),
                        Color(0xFFFFE89A),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🎉',
                      style: TextStyle(fontSize: 48),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Title
              Text(
                'Chúc mừng bạn đã hoàn thành bài học!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),

              if (lesson != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  lesson!.titleVi,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryBlueDark,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // 2-Column Achievement Metrics Block
              Row(
                children: [
                  // Column 1: XP Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainerLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFECC8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.stars_rounded,
                              color: Color(0xFFD97706),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+$xpGained XP',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Điểm kinh nghiệm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Column 2: Streak Flame
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE0CC),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '🔥',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$streakDays ngày liên tục',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD84315),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🔥 Chuỗi Streak: $streakDays ngày liên tục',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFBF360C),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (accuracyRate != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.mainBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Độ chính xác: ${(accuracyRate! * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Status Card: Next Lesson Unlocked
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successContainerLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ Đã mở khóa: $effectiveNextTitle',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Sẵn sàng cho bài học tiếp theo trên lộ trình của bạn',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1B6B46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Main CTA Button
              HiButton(
                text: 'TIẾP TỤC HỌC ➔',
                size: HiButtonSize.lg,
                isFullWidth: true,
                variant: HiButtonVariant.primary,
                onPressed: onContinue,
              ),

              if (onReviewLesson != null) ...[
                const SizedBox(height: AppSpacing.sm),
                HiButton(
                  text: 'Xem lại bài học',
                  size: HiButtonSize.md,
                  isFullWidth: true,
                  variant: HiButtonVariant.ghost,
                  onPressed: onReviewLesson,
                ),
              ],

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
