import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

/// Progress and persistence status header for the active SRS flashcard review session.
class FlashcardProgressHeader extends StatelessWidget {
  final int currentIndex;
  final int totalCards;
  final int remainingCards;
  final bool hasSavedOffline;

  const FlashcardProgressHeader({
    super.key,
    required this.currentIndex,
    required this.totalCards,
    required this.remainingCards,
    this.hasSavedOffline = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentStep = (currentIndex + 1).clamp(1, totalCards == 0 ? 1 : totalCards);
    final progress = totalCards == 0 ? 1.0 : (currentIndex / totalCards).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top info row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thẻ $currentStep / $totalCards',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                HiChip(
                  label: 'Còn lại: $remainingCards',
                  status: HiChipStatus.info,
                ),
                const SizedBox(width: AppSpacing.xs),
                if (hasSavedOffline)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.limeGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đã lưu SQLite',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.limeGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Animated linear progress bar
        ClipRRect(
          borderRadius: AppRadius.borderFull,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.limeGreen),
          ),
        ),
      ],
    );
  }
}
