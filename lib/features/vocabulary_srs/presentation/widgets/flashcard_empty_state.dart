import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

/// Screen widget displayed when the SRS due queue is empty or all cards
/// scheduled for today have been reviewed.
class FlashcardEmptyState extends StatelessWidget {
  final int completedReviewsCount;
  final double accuracyRate;
  final VoidCallback onLoadMoreWords;
  final VoidCallback? onBackToHome;

  const FlashcardEmptyState({
    super.key,
    required this.completedReviewsCount,
    required this.accuracyRate,
    required this.onLoadMoreWords,
    this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracyPercent = (accuracyRate * 100).toStringAsFixed(0);

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: HiCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondaryBlue, width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primaryBlueDark,
                  size: 38,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Xuất Sắc! Hoàn Thành Ôn Tập',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'Không còn thẻ nào đến hạn hôm nay. Thuật toán SM-2 đã tự động xếp lịch ôn tập tối ưu cho các ngày tiếp theo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Session Performance Summary Badges
              if (completedReviewsCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatPill(
                      context: context,
                      label: 'Đã ôn tập',
                      value: '$completedReviewsCount thẻ',
                      color: AppColors.primaryBlueDark,
                      bgColor: AppColors.primaryBlueLight,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatPill(
                      context: context,
                      label: 'Tỷ lệ nhớ',
                      value: '$accuracyPercent%',
                      color: AppColors.success,
                      bgColor: AppColors.successContainerLight,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Actions
              HiButton(
                text: 'Học thêm 15 từ mới',
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                isFullWidth: true,
                onPressed: onLoadMoreWords,
              ),
              if (onBackToHome != null) ...[
                const SizedBox(height: AppSpacing.sm),
                HiButton(
                  text: 'Quay về Trang Chủ',
                  icon: const Icon(Icons.home_rounded, size: 18),
                  variant: HiButtonVariant.secondary,
                  size: HiButtonSize.md,
                  isFullWidth: true,
                  onPressed: onBackToHome,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
