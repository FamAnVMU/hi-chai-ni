import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/sm2_engine.dart';
import '../../domain/srs_models.dart';

/// Rating action bar presenting the 4 SuperMemo 2 choices (Again, Hard, Good, Easy)
/// with dynamic interval previews and double-tap lockout protection.
class FlashcardRatingBar extends StatelessWidget {
  final Map<SrsRating, int> estimatedIntervals;
  final bool isProcessing;
  final ValueChanged<SrsRating> onRatingSelected;

  const FlashcardRatingBar({
    super.key,
    required this.estimatedIntervals,
    required this.isProcessing,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Row(
          children: [
            _buildRatingButton(
              context: context,
              rating: SrsRating.again,
              label: 'Quên',
              color: AppColors.error,
              isNarrow: isNarrow,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildRatingButton(
              context: context,
              rating: SrsRating.hard,
              label: 'Khó',
              color: AppColors.warning,
              isNarrow: isNarrow,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildRatingButton(
              context: context,
              rating: SrsRating.good,
              label: 'Nhớ',
              color: AppColors.primaryBlueDark,
              isNarrow: isNarrow,
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildRatingButton(
              context: context,
              rating: SrsRating.easy,
              label: 'Dễ',
              color: AppColors.success,
              isNarrow: isNarrow,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingButton({
    required BuildContext context,
    required SrsRating rating,
    required String label,
    required Color color,
    required bool isNarrow,
  }) {
    final theme = Theme.of(context);
    final days = estimatedIntervals[rating] ?? 1;
    final intervalText = Sm2Engine.formatIntervalExplanation(rating, days);

    return Expanded(
      child: Semantics(
        label: 'Đánh giá $label: ôn lại sau $intervalText',
        button: true,
        enabled: !isProcessing,
        child: Material(
          color: color.withAlpha(20),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderMd,
            side: BorderSide(
              color: isProcessing ? color.withAlpha(80) : color,
              width: 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: isProcessing ? null : () => onRatingSelected(rating),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isNarrow ? AppSpacing.sm : AppSpacing.md,
                horizontal: AppSpacing.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isProcessing
                          ? AppColors.disabledText
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    intervalText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isNarrow ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
