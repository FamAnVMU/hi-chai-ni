import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../dictionary/dictionary.dart';

/// Clean 2x2 grid providing instant single-tap access to primary learning surfaces.
class HomeQuickActionsGrid extends StatelessWidget {
  final VoidCallback onNavigateLearning;
  final VoidCallback onNavigateReview;
  final VoidCallback onNavigateAiTutor;

  const HomeQuickActionsGrid({
    super.key,
    required this.onNavigateLearning,
    required this.onNavigateReview,
    required this.onNavigateAiTutor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Truy Cập Nhanh',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context: context,
                icon: Icons.school_rounded,
                iconColor: AppColors.primaryBlueDark,
                title: 'Bài học HSK',
                subtitle: 'Theo lộ trình',
                onTap: onNavigateLearning,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionTile(
                context: context,
                icon: Icons.psychology_rounded,
                iconColor: AppColors.warning,
                title: 'Ôn tập thẻ',
                subtitle: 'Thuật toán SM-2',
                onTap: onNavigateReview,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context: context,
                icon: Icons.menu_book_rounded,
                iconColor: AppColors.information,
                title: 'Từ điển tra cứu',
                subtitle: 'Tra offline tức thì',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildActionTile(
                context: context,
                icon: Icons.auto_awesome_rounded,
                iconColor: AppColors.primaryBlue,
                title: 'AI Voice Tutor',
                subtitle: 'Luyện hội thoại',
                onTap: onNavigateAiTutor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        splashColor: iconColor.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkForestCard : AppColors.cardBackground,
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: isDark ? AppColors.darkForestBorder : AppColors.border,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: AppDimensions.iconMd),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
