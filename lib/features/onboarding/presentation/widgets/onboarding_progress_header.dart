import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class OnboardingProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const OnboardingProgressHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (currentStep / totalSteps).clamp(0.0, 1.0);

    final stepLabels = const [
      '1. AI Trợ Giảng',
      '2. Năng Lực',
      '3. Cá Nhân Hóa',
    ];

    return Semantics(
      label: 'Tiến trình thiết lập: Bước $currentStep trên $totalSteps',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bước $currentStep / $totalSteps',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlueDark,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}% Hoàn thành',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0.0, end: progress),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlueDark,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 340;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(totalSteps, (index) {
                    final stepNum = index + 1;
                    final isDone = stepNum < currentStep;
                    final isCurrent = stepNum == currentStep;

                    Color circleColor;
                    Color iconColor;
                    Widget indicator;

                    if (isDone) {
                      circleColor = AppColors.primaryBlueDark;
                      iconColor = Colors.white;
                      indicator = Icon(Icons.check, size: 12, color: iconColor);
                    } else if (isCurrent) {
                      circleColor = AppColors.primaryBlueDark;
                      iconColor = Colors.white;
                      indicator = Text(
                        '$stepNum',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    } else {
                      circleColor = theme.colorScheme.surfaceContainerHighest;
                      iconColor = theme.colorScheme.onSurfaceVariant;
                      indicator = Text(
                        '$stepNum',
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }

                    return Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: circleColor,
                              shape: BoxShape.circle,
                            ),
                            child: indicator,
                          ),
                          const SizedBox(width: 4),
                          if (!isNarrow)
                            Flexible(
                              child: Text(
                                stepLabels[index],
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent
                                      ? AppColors.primaryBlueDark
                                      : (isDone
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
