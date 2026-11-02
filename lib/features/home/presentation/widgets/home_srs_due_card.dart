import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

/// Clean Modern Card alerting the learner about spaced repetition (SRS) cards due for review today.
class HomeSrsDueCard extends StatelessWidget {
  final int dueCount;
  final VoidCallback onStartReview;

  const HomeSrsDueCard({
    super.key,
    required this.dueCount,
    required this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasDue = dueCount > 0;

    return HiCard(
      borderColor: hasDue
          ? (isDark ? AppColors.accentBlue.withAlpha(120) : AppColors.primaryBlue.withAlpha(120))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                color: isDark ? AppColors.accentBlue : AppColors.primaryBlueDark,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ôn tập ngắt quãng (SM-2)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              HiChip(
                label: hasDue ? '$dueCount thẻ đến hạn' : 'Đã hoàn thành',
                status: hasDue ? HiChipStatus.warning : HiChipStatus.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasDue
                ? 'Hôm nay có $dueCount thẻ từ vựng cần củng cố trí nhớ dài hạn theo thuật toán SM-2.'
                : 'Tuyệt vời! Bạn đã hoàn thành tất cả các thẻ từ vựng cần ôn tập của ngày hôm nay.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          HiButton(
            text: hasDue ? 'Bắt đầu ôn tập ngay' : 'Xem lại thẻ đã học',
            icon: Icon(hasDue ? Icons.play_arrow_rounded : Icons.check_circle_outline_rounded),
            variant: hasDue ? HiButtonVariant.primary : HiButtonVariant.secondary,
            size: HiButtonSize.md,
            isFullWidth: true,
            onPressed: onStartReview,
          ),
        ],
      ),
    );
  }
}
