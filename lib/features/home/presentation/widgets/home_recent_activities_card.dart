import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Card listing recent meaningful learning activities with relative timestamps,
/// or a clean empty state for fresh learners.
class HomeRecentActivitiesCard extends StatelessWidget {
  final List<RecentActivityItem> activities;
  final VoidCallback onStartLearning;

  const HomeRecentActivitiesCard({
    super.key,
    required this.activities,
    required this.onStartLearning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Hoạt Động Gần Đây',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (activities.isNotEmpty)
              Text(
                '${activities.length} hoạt động gần nhất',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (activities.isEmpty)
          HiCard(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.md,
            ),
            child: HiEmptyState(
              title: 'Chưa có hoạt động học nào',
              description:
                  'Mỗi khi bạn ôn tập từ vựng, luyện viết hoặc đàm thoại AI, tiến trình sẽ được tự động ghi lại tại đây!',
              icon: Icons.history_rounded,
              actionText: 'Bắt đầu học ngay',
              onAction: onStartLearning,
            ),
          )
        else
          HiCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, _) => Divider(
                height: AppSpacing.md,
                color: theme.colorScheme.outlineVariant.withAlpha(50),
              ),
              itemBuilder: (context, index) {
                final item = activities[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: _getIconColor(item.type).withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIcon(item.type),
                          color: _getIconColor(item.type),
                          size: AppDimensions.iconSm,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        item.formattedRelativeTime(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  IconData _getIcon(ActivityType type) {
    switch (type) {
      case ActivityType.srsReview:
        return Icons.psychology_rounded;
      case ActivityType.aiTutor:
        return Icons.auto_awesome_rounded;
      case ActivityType.lesson:
        return Icons.school_rounded;
      case ActivityType.hanziWriting:
        return Icons.edit_note_rounded;
      case ActivityType.pronunciationShadowing:
        return Icons.record_voice_over_rounded;
      case ActivityType.reading:
        return Icons.chrome_reader_mode_rounded;
      case ActivityType.dictionary:
        return Icons.menu_book_rounded;
    }
  }

  Color _getIconColor(ActivityType type) {
    switch (type) {
      case ActivityType.srsReview:
        return Colors.orange;
      case ActivityType.aiTutor:
        return AppColors.primaryBlueDark;
      case ActivityType.lesson:
        return Colors.blueAccent;
      case ActivityType.hanziWriting:
        return Colors.purpleAccent;
      case ActivityType.pronunciationShadowing:
        return Colors.teal;
      case ActivityType.reading:
        return Colors.amber;
      case ActivityType.dictionary:
        return Colors.indigoAccent;
    }
  }
}
