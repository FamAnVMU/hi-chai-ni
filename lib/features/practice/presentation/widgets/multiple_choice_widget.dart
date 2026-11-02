import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class MultipleChoiceWidget extends StatelessWidget {
  final ExerciseDefinition definition;
  final int? selectedIndex;
  final ScoringResult? result;
  final ValueChanged<int> onSelectOption;

  const MultipleChoiceWidget({
    super.key,
    required this.definition,
    required this.selectedIndex,
    this.result,
    required this.onSelectOption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = result != null;

    return Column(
      children: List.generate(definition.options.length, (idx) {
        final option = definition.options[idx];
        final isSelected = selectedIndex == idx;

        Color borderColor = theme.colorScheme.outlineVariant.withAlpha(80);
        Color bgColor = theme.colorScheme.surface;
        Color textColor = theme.colorScheme.onSurface;

        if (isSubmitted) {
          if (idx == definition.correctOptionIndex) {
            borderColor = AppColors.primaryBlueDark;
            bgColor = AppColors.primaryBlueDark.withAlpha(20);
            textColor = AppColors.primaryBlueDark;
          } else if (isSelected && !result!.isCorrect) {
            borderColor = AppColors.errorLight;
            bgColor = AppColors.errorLight.withAlpha(20);
            textColor = AppColors.errorLight;
          }
        } else if (isSelected) {
          borderColor = AppColors.primaryBlueDark;
          bgColor = AppColors.primaryBlueDark.withAlpha(15);
          textColor = AppColors.primaryBlueDark;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: InkWell(
            onTap: isSubmitted ? null : () => onSelectOption(idx),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? (isSubmitted && !result!.isCorrect
                              ? AppColors.errorLight
                              : AppColors.primaryBlueDark)
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      String.fromCharCode(65 + idx), // A, B, C, D
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      option,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isSubmitted && idx == definition.correctOptionIndex)
                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlueDark, size: 20)
                  else if (isSubmitted && isSelected && !result!.isCorrect)
                    const Icon(Icons.cancel_rounded, color: AppColors.errorLight, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
