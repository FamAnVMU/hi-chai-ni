import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Card displaying the greeting, daily goal progress, and real active study streak.
class HomeWelcomeStreakCard extends StatelessWidget {
  final HomeDashboardData data;

  const HomeWelcomeStreakCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final streak = data.streak;

    final hasStreak = streak.currentStreak > 0;
    final studiedToday = streak.hasStudiedToday;

    String streakTitle;
    String streakSubtitle;

    if (hasStreak) {
      streakTitle = 'Chuỗi học ${streak.currentStreak} ngày liên tiếp! 🔥';
      if (studiedToday) {
        streakSubtitle = 'Bạn đã hoàn thành hoạt động hôm nay. Tiếp tục phát huy nhé!';
      } else {
        streakSubtitle = 'Học ít nhất 1 bài ngay hôm nay để giữ vững chuỗi!';
      }
    } else {
      streakTitle = 'Bắt đầu chuỗi học tập mới 🌱';
      streakSubtitle = 'Mỗi ngày học một chút để hình thành phản xạ tiếng Trung tự nhiên.';
    }

    return HiCard(
      backgroundColor: isDark
          ? AppColors.darkForestCard
          : theme.colorScheme.primaryContainer.withAlpha(120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Streak Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: hasStreak
                      ? Colors.orange.withAlpha(isDark ? 50 : 30)
                      : theme.colorScheme.primary.withAlpha(isDark ? 50 : 30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasStreak
                      ? Icons.local_fire_department_rounded
                      : Icons.wb_sunny_rounded,
                  color: hasStreak ? Colors.orange : AppColors.limeGreen,
                  size: AppDimensions.iconLg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.greeting}, ${data.learnerName}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streakTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            streakSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Daily Target Progress
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mục tiêu hôm nay: ${streak.todayItemsCompleted}/${data.dailyGoalWords} từ • ${(streak.todayDurationSeconds / 60).round()}/${data.dailyGoalMinutes} phút',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (data.isDailyGoalAchieved) ...[
                const SizedBox(width: AppSpacing.xs),
                const HiChip(
                  label: 'Đạt mục tiêu ⭐',
                  status: HiChipStatus.success,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          HiLinearProgress(value: data.dailyGoalProgressRatio),
        ],
      ),
    );
  }
}
