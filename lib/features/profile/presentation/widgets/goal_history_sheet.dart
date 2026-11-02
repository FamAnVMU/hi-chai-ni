import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/user_profile.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';

class GoalHistorySheet extends StatelessWidget {
  final List<GoalHistoryRecord> history;

  const GoalHistorySheet({
    super.key,
    required this.history,
  });

  static Future<void> show({
    required BuildContext context,
    required List<GoalHistoryRecord> history,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoalHistorySheet(history: history),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: AppSpacing.screenPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primaryBlueDark),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lịch Sử Thay Đổi Mục Tiêu',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hệ thống lưu giữ mọi lần điều chỉnh mục tiêu kèm lý do thực tế của người học.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: HiEmptyState(
                      icon: Icons.track_changes_outlined,
                      title: 'Chưa có thay đổi mục tiêu nào',
                      description: 'Khi bạn điều chỉnh mục tiêu và lưu lý do, lịch sử sẽ được hiển thị tại đây.',
                    ),
                  )
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final dateStr = '${item.changedAt.day}/${item.changedAt.month}/${item.changedAt.year} '
                          '${item.changedAt.hour.toString().padLeft(2, '0')}:${item.changedAt.minute.toString().padLeft(2, '0')}';

                      return HiCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    HiChip(label: 'HSK ${item.previousTargetHsk}', status: HiChipStatus.neutral),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.arrow_forward_rounded, size: 14),
                                    ),
                                    HiChip(label: 'HSK ${item.newTargetHsk}', status: HiChipStatus.success),
                                  ],
                                ),
                                Text(
                                  dateStr,
                                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Thời gian: ${item.previousDailyMinutes}p ➔ ${item.newDailyMinutes}p/ngày • ${item.newPurpose.displayName}',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote_rounded, size: 14, color: AppColors.primaryBlueDark),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.reason,
                                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          HiButton(
            text: 'Đóng',
            variant: HiButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
